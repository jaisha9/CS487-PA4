# PA4 Submission: TaskFlow Pipeline

## Student Information

| Field | Value |
|---|---|
| Name | Jaisha |
| Roll Number | 27100246 |
| GitHub Repository URL | https://github.com/jaisha9/CS487-PA4 |
| Resource Group | `rg-sp26-27100246` |
| Assigned Region | `ukwest` |

## Evidence Rules

- Use relative image paths, for example: `![AKS nodes](docs/5.2.png)`.
- Each image below has a short explanation of what it proves.
- Azure Portal screenshots show the resource name and enough page context to identify the service.
- CLI screenshots show the command and the output.
- Secrets such as function keys, ACR passwords, and storage connection strings are masked.

## Task 1: App Service Web App

### Evidence 1.1: Forked Repository

![Forked repository](docs/1.1.png)

This is my working fork of the PA4 starter repository. It is the repo I used for the deployment.

### Evidence 1.2: App Service Overview

![Web App overview](docs/1.2.png)

This shows the Web App `pa4-27100246` running in `rg-sp26-27100246` in `ukwest`.

### Evidence 1.3: Deployment Center / GitHub Actions

![Deployment Center](docs/1.3.png)

This shows the Web App deployment path connected to my GitHub fork. It proves the frontend is deployed from GitHub.

### Evidence 1.4: Live Web UI

![Live Web UI](docs/1.4.png)

The TaskFlow page loads in the browser, so App Service is serving the frontend correctly.

### Evidence 1.5: Web App Settings

![Web App settings](docs/1.5.png)

The Web App has `FUNCTION_START_URL` and `FUNCTION_STATUS_URL` configured. These settings point the UI at the Durable Function.

## Task 2: Azure Container Registry

### Evidence 2.1: ACR Overview

![ACR overview](docs/2.1.png)

This shows the registry `pa427100246` in the correct resource group. It is the registry used for all container images.

### Evidence 2.2: Docker Builds

![Docker builds](docs/2.2.png)

This shows successful builds for `validate-api`, `report-job`, and `func-app`. Each image came from its matching folder.

### Evidence 2.3: ACR Repositories

![ACR repositories](docs/2.3.png)

The registry contains the three required repositories. This proves the images were pushed to ACR.

### Evidence 2.4: CLI Tag List

![ACR tag list](docs/2.4.png)

This CLI output confirms the repositories exist and each one has the `v1` tag. It is a direct check from the terminal.

### Evidence 2.5: Portal Repository View

![ACR portal repos](docs/2.5.png)

This is the portal view of the same registry repositories. It matches the CLI output and confirms the push worked.

## Task 3: Durable Function Implementation

### Evidence 3.1: Completed Function Code

[function_app.py](function-app/function_app.py)

The orchestrator first calls validation and then decides whether to stop or create a report job. The activities are split cleanly so each service only does one job.

### Evidence 3.2: Local Function Handler Listing

![Local function handlers](docs/3.1.png)

This shows the Durable Functions host discovering the HTTP starter, orchestrator, and activity functions.

### Evidence 3.3: Durable Runtime Loaded

![Durable runtime loaded](docs/3.2.png)

This second run confirms the same handlers are loaded and ready. It proves the local function app starts correctly.

## Task 4: Function App Container Deployment

### Evidence 4.1: Function App Settings

![Function App settings](docs/4.1.png)

This shows the Function App app settings after the managed-identity storage fix was applied. The `AzureWebJobsStorage__...` values are set there.

### Evidence 4.2: Container Image Configuration

![Function App deployment center](docs/4.3.png)

This shows the Function App deployment setup pointing at Azure Container Registry. It confirms the container source and image name.

### Evidence 4.3: Expected Failed Status Before Downstream Wiring

![Failed orchestration status](docs/4.4.png)

The orchestration starts but fails because `VALIDATE_URL` is still a placeholder. That is expected before Task 5 is wired in.

## Task 5: AKS Validator

### Evidence 5.1: AKS Cluster

![AKS overview](docs/5.1.png)

This shows the AKS cluster is created and running in `ukwest`. The cluster belongs to `rg-sp26-27100246`.

### Evidence 5.2: Kubernetes Nodes and Pods

![kubectl nodes and pods](docs/5.2.png)

The node is Ready and the validator pod is Running. That means the deployment scheduled correctly.

### Evidence 5.3: Kubernetes Service

![kubectl service](docs/5.3.png)

This shows the `validate-service` LoadBalancer and its external IP. That is the public entry point for the validator.

### Evidence 5.4.1: Validator Health Check

![Validator health](docs/5.4.1.png)

The `/health` endpoint returns `ok`. This proves the validator service is reachable.

### Evidence 5.4.2: Validator Accepts Good Orders

![Validator valid order](docs/5.4.2.png)

The order with `qty=2` returns `valid: true`. This is the normal accept path.

### Evidence 5.4.3: Validator Rejects Large Orders

![Validator invalid order](docs/5.4.3.png)

The order with `qty=999` returns `valid: false` and `quantity exceeds limit`. This is the rejection rule used by the pipeline.

### Evidence 5.5.1: Function App `VALIDATE_URL`

![VALIDATE_URL terminal](docs/5.5.1.png)

This CLI output shows `VALIDATE_URL` saved on the Function App. It points the Durable Function to the AKS validator.

### Evidence 5.5.2: Function App `VALIDATE_URL` in Portal

![VALIDATE_URL portal](docs/5.5.2.png)

The portal shows the same `VALIDATE_URL` setting. This is the value the orchestrator reads at runtime.

### Evidence 5.6: AKS Idle Behavior

The AKS node stays running even when no orders are being processed. That is expected because AKS is an always-on cluster, unlike ACI jobs.

## Task 6: ACI Report Job

### Evidence 6.1: Blob Container

![Reports container](docs/6.1.png)

This shows the `reports` container in the storage account. All generated PDFs are stored there.

### Evidence 6.2: Manual ACI Run

![ACI succeeded](docs/6.2.png)

The manual report container `ci-report-test` finished in `Succeeded` state. It is a one-shot job, so it exits after the PDF is written.

### Evidence 6.3: ACI Logs

![ACI logs](docs/6.3.png)

The logs show the report job running and uploading the PDF. This proves the container executed the report script.

### Evidence 6.4: Generated PDF

![Blob PDF list](docs/6.4.png)

`TEST-001.pdf` appears in the blob container. That confirms the ACI wrote the generated file to storage.

### Evidence 6.5: Managed Identity and Report Settings

![Report settings](docs/6.5.png)

This shows the report-related settings on the Function App, including the storage URL and ACR details. The report job uses the attached user-assigned identity `mi-pa4-27100246` to upload the PDF.

## Task 7: End-to-End Pipeline

### Evidence 7.1: Web App Wiring

![Web App wiring](docs/7.1.png)

This shows `FUNCTION_START_URL` and `FUNCTION_STATUS_URL` configured on the Web App. The frontend uses them to start and poll the Durable orchestration.

### Evidence 7.2: Happy Path Form

![Happy path before submit](docs/7.2.png)

This is the order form before submit. It shows the valid happy-path order that should complete.

### Evidence 7.3: Happy Path Running

![Happy path running](docs/7.3.png)

The UI is in Running state after submit. That means the frontend successfully started the Durable orchestration.

### Evidence 7.4: Happy Path Completed

![Happy path completed](docs/7.4.png)

The UI shows Completed and gives a PDF report link. This is the final success state for the valid order.

### Evidence 7.5: Backend Function Logs

![Backend function logs](docs/7.5.png)

The Function App logs show `report_activity` running and the orchestrator completing. This traces the order through the backend.

### Evidence 7.6: Blob PDFs

![Blob PDF list](docs/7.6.png)

The storage container shows the generated PDFs, including the happy-path report. This proves the backend wrote the file to Blob Storage.

### Evidence 7.7.1: Validator Logs

![Validator logs](docs/7.7.1.png)

The validator logs show the `/health` and `/validate` requests coming in. This is proof that the orchestrator called the AKS service.

### Evidence 7.7: Report ACI List

![ACI list](docs/7.7.png)

The container list shows the report jobs that were created during the pipeline. It ties the happy-path order to an ACI instance.

### Evidence 7.8.1: Reject Path Form

![Reject form](docs/7.8.1.png)

This shows the reject-path order with `qty=999` entered in the form. It is the invalid order used for the rejection test.

### Evidence 7.8.2: Reject Path Result

![Reject result](docs/7.8.2.png)

The UI shows the order rejected with the correct reason. This proves the invalid order is blocked before a report is created.

### Evidence 7.8: Reject Path Screen

![Reject screen](docs/7.8.png)

This is another reject-path view of the same invalid order. It shows the final rejected state in the frontend.

### Evidence 7.9: Resource Group Overview

![Resource group overview](docs/7.9.png)

This shows all the major resources in the group, including App Service, Function App, AKS, ACR, storage, and the managed identity. It is a good summary of the finished pipeline.

## Task 8: Write-up and Architecture Diagram

### Evidence 8.1: Architecture Diagram

```mermaid
flowchart TD
    github[GitHub fork] --> deploy[App Service Deployment Center]
    deploy --> web[App Service Web App<br/>pa4-27100246]
    browser[User browser] --> web
    web -->|FUNCTION_START_URL| func[Durable Function App<br/>pa4-27100246-func]
    func -->|validate_activity| aks[AKS validate-api<br/>pa4-27100246]
    func -->|report_activity creates job| aci[Azure Container Instance<br/>report-job]
    aci -->|uploads PDF| blob[Blob Storage<br/>pa427100246/reports]
    acr[Azure Container Registry<br/>pa427100246] --> func
    acr --> aks
    acr --> aci
    mi[User-assigned Managed Identity<br/>mi-pa4-27100246] --> func
    mi --> aci
    mi --> blob
    mi --> rg[Resource Group IAM<br/>rg-sp26-27100246]
```

This diagram matches the deployed pipeline. It shows GitHub, App Service, Durable Functions, AKS, ACI, Blob Storage, ACR, and managed identity.

### Question 8.2: Service Selection

TaskFlow uses App Service for the frontend because it is simple to host and easy to wire to GitHub deployment. It keeps the browser UI always available without managing servers.

TaskFlow uses Durable Functions for the workflow because the order has multiple steps and needs state between them. The orchestrator can wait, branch, and return a clean status URL.

TaskFlow uses AKS for the validator because it is a normal always-on API service behind a LoadBalancer. That makes it a good fit for the shared validation endpoint.

TaskFlow uses ACI for the report job because each report is short lived and runs once per order. ACI fits that pattern better than keeping another service running all the time.

### Question 8.3: ACI vs AKS

AKS stays up even when no orders are being processed, so it has a steady baseline cost. ACI only runs when the report job is created, so it is better for one-shot work.

Operationally, AKS needs a cluster, node management, and Kubernetes objects. ACI is simpler because it only needs the container image and runtime settings.

For this assignment, AKS is the validator service and ACI is the report worker. That split keeps the always-on part separate from the per-order batch job.

### Question 8.4: Durable Functions vs Plain HTTP

Durable Functions solves the problem of long-running work by keeping orchestration state for me. A plain HTTP handler would have to hold the request open or invent its own state store.

It also solves branching and retries in a clean way. The workflow can stop on invalid orders and continue to report generation only when validation passes.

### Question 8.5: Cost Review

<img width="1777" height="1038" alt="Screenshot 2026-05-08 at 2 34 17 AM" src="https://github.com/user-attachments/assets/f79a687a-f321-4051-b620-132f44d21fc9" />

The AKS cluster is the most expensive part because it keeps a node running all the time.

ACI is cheaper for the report step because it only runs when an order needs a PDF. App Service, storage, and ACR are smaller by comparison in this setup.

### Question 8.6: Challenges Faced

The first issue was the Function App storage policy. I had to switch `AzureWebJobsStorage` to the managed-identity settings because the subscription blocked the default storage connection.

The second issue was the AKS kubeconfig. My local kubeconfig was malformed, so I rebuilt it with `az aks get-credentials --file /tmp/pa4-kubeconfig` and used that file directly.

I also had to adjust the Function App container deployment command because the Azure CLI version here did not accept the old registry flags. Switching to `--image` and `--registry-*` fixed it.
