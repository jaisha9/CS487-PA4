import azure.functions as func
import azure.durable_functions as df
import hashlib
import json
import os
import re
import time

import requests

app = df.DFApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="orchestrators/my_orchestrator", methods=["POST"])
@app.durable_client_input(client_name="client")
async def http_starter(req: func.HttpRequest, client: df.DurableOrchestrationClient):
    order = req.get_json()
    instance_id = await client.start_new("my_orchestrator", client_input=order)
    return client.create_check_status_response(req, instance_id)

@app.orchestration_trigger(context_name="context")
def my_orchestrator(context: df.DurableOrchestrationContext):
    order = context.get_input()
    validation = yield context.call_activity("validate_activity", order)

    if not validation.get("valid"):
        return {
            "status": "rejected",
            "reason": validation.get("reason", "validation failed"),
            "order_id": validation.get("order_id", order.get("order_id")),
        }

    report_url = yield context.call_activity("report_activity", order)
    return {
        "status": "completed",
        "order_id": order.get("order_id"),
        "report_url": report_url,
    }

@app.activity_trigger(input_name="order")
def validate_activity(order: dict) -> dict:
    validate_url = os.environ["VALIDATE_URL"]
    response = requests.post(validate_url, json=order, timeout=30)
    response.raise_for_status()
    return response.json()


def _container_group_name(order_id: str) -> str:
    normalized = re.sub(r"[^a-z0-9-]", "-", order_id.lower()).strip("-")
    normalized = re.sub(r"-+", "-", normalized) or "order"
    digest = hashlib.sha1(order_id.encode("utf-8")).hexdigest()[:8]
    return f"ci-report-{normalized[:40]}-{digest}"

@app.activity_trigger(input_name="order")
def report_activity(order: dict) -> str:
    from azure.mgmt.containerinstance import ContainerInstanceManagementClient
    from azure.mgmt.containerinstance.models import (
        ContainerGroup, Container, ResourceRequirements, ResourceRequests,
        ImageRegistryCredential, EnvironmentVariable, OperatingSystemTypes,
        ContainerGroupRestartPolicy, ContainerGroupIdentity, ResourceIdentityType
    )
    from azure.identity import DefaultAzureCredential

    sub_id   = os.environ["SUBSCRIPTION_ID"]
    rg       = os.environ["REPORT_RG"]
    loc      = os.environ["REPORT_LOCATION"]
    image    = os.environ["REPORT_IMAGE"]
    order_id = order["order_id"]
    name     = _container_group_name(order_id)

    client = ContainerInstanceManagementClient(DefaultAzureCredential(), sub_id)
    
    # Construct the Managed Identity Resource ID
    rollnum = rg.split("-")[-1]
    mi_id = f"/subscriptions/{sub_id}/resourcegroups/{rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-pa4-{rollnum}"
    
    group = ContainerGroup(
        location=loc,
        os_type=OperatingSystemTypes.linux,
        restart_policy=ContainerGroupRestartPolicy.never,
        identity=ContainerGroupIdentity(
            type=ResourceIdentityType.user_assigned,
            user_assigned_identities={mi_id: {}},
        ),
        image_registry_credentials=[ImageRegistryCredential(
            server=os.environ["ACR_SERVER"],
            username=os.environ["ACR_USERNAME"],
            password=os.environ["ACR_PASSWORD"],
        )],
        containers=[Container(
            name="report",
            image=image,
            resources=ResourceRequirements(
                requests=ResourceRequests(cpu=1.0, memory_in_gb=1.5),
            ),
            environment_variables=[
                EnvironmentVariable(name="ORDER_ID", value=order_id),
                EnvironmentVariable(name="ORDER_JSON", value=json.dumps(order)),
                EnvironmentVariable(
                    name="STORAGE_ACCOUNT_URL",
                    value=os.environ["STORAGE_ACCOUNT_URL"],
                ),
                EnvironmentVariable(
                    name="AZURE_CLIENT_ID",
                    value=os.environ["AZURE_CLIENT_ID"],
                ),
            ],
        )],
    )

    client.container_groups.begin_create_or_update(rg, name, group).result()

    final_state = None
    for _ in range(60):
        info = client.container_groups.get(rg, name)
        final_state = info.instance_view.state if info.instance_view else None
        if final_state in ("Succeeded", "Failed"):
            break
        time.sleep(5)

    if final_state != "Succeeded":
        raise RuntimeError(f"Report container {name} finished with state {final_state}")

    return f"{os.environ['STORAGE_ACCOUNT_URL']}/reports/{order_id}.pdf"
