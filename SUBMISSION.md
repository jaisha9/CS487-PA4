# PA4 Submission: TaskFlow Pipeline

## Student Information

| Field | Value |
|---|---|
| Name | TODO |
| Roll Number | 27100246 |
| GitHub Repository URL | TODO |
| Resource Group | `rg-sp26-27100246` |
| Assigned Region | `ukwest` |

## Evidence Rules

- Put screenshots in `docs/` using the filenames below.
- Mask function keys, ACR passwords, and storage connection strings.
- Portal screenshots must show resource name and enough page context.
- CLI screenshots must show the command and output.

## Task 1: App Service Web App

### Evidence 1.1: Forked Repository

![Forked repository](docs/01-github-fork.png)

Description: This screenshot shows my GitHub fork containing the PA4 starter structure.

### Evidence 1.2: App Service Overview

![Web App overview](docs/02-webapp-overview.png)

Description: This shows Web App `pa4-27100246` running in resource group `rg-sp26-27100246` in `ukwest`.

### Evidence 1.3: Deployment Center / GitHub Actions

![Deployment Center](docs/03-webapp-deployment-center.png)

Description: This shows the App Service deployment connection to my GitHub fork.

### Evidence 1.4: Live Web UI

![Live Web UI](docs/04-live-web-ui.png)

Description: This proves the public App Service URL is serving the TaskFlow frontend.

## Task 2: Azure Container Registry

### Evidence 2.1: ACR Overview

![ACR overview](docs/05-acr-overview.png)

Description: This shows Azure Container Registry `crpa427100246` in the PA4 resource group.

### Evidence 2.2: Docker Builds

![Docker builds](docs/06-docker-builds.png)

Description: This shows successful local Docker builds for `validate-api`, `report-job`, and `func-app`.

### Evidence 2.3: ACR Repositories

![ACR repositories](docs/07-acr-repositories.png)

Description: This confirms `validate-api:v1`, `report-job:v1`, and `func-app:v1` were pushed to ACR.

## Task 3: Durable Function Implementation

### Evidence 3.1: Completed Function Code

[function_app.py](function-app/function_app.py)

Description: The orchestrator validates an order, rejects invalid orders, and creates a report job for valid orders.

### Evidence 3.2: Local Function Handler Listing

![Function handlers](docs/08-func-start-handlers.png)

Description: This shows the Durable Functions runtime discovered the starter, orchestrator, and activities.

## Task 4: Function App Container Deployment

### Evidence 4.1: Function App Container Configuration

![Function container config](docs/09-function-container-config.png)

Description: This shows Function App `pa4-27100246-func` using the `func-app:v1` image from ACR.

### Evidence 4.2: Managed Identity Storage Settings

![Function identity](docs/10-function-identity-mi.png)

![Function storage settings](docs/11-function-storage-settings.png)

Description: These screenshots show `mi-pa4-27100246` attached and the managed-identity `AzureWebJobsStorage__...` settings applied.

### Evidence 4.3: Orchestration Smoke Test

![Orchestration start](docs/12-orchestration-start.png)

Description: This shows the HTTP starter returning an orchestration id and `statusQueryGetUri`.

### Evidence 4.4: Expected Failed Status Before Downstream Wiring

![Expected failed status](docs/13-expected-failed-status.png)

Description: This failure is expected before `VALIDATE_URL` is wired to the AKS validator.

## Task 5: AKS Validator

### Evidence 5.1: AKS Cluster

![AKS overview](docs/14-aks-overview.png)

Description: This shows AKS cluster `pa4-27100246` in the assigned region and resource group.

### Evidence 5.2: Kubernetes Nodes and Pods

![kubectl nodes pods](docs/15-kubectl-nodes-pods.png)

Description: This shows the AKS node is ready and the validator pod is running.

### Evidence 5.3: Kubernetes Service

![kubectl service](docs/16-kubectl-service.png)

Description: This shows the LoadBalancer external IP and port `8080`.

### Evidence 5.4: Validator API Tests

![Validator curl tests](docs/17-validator-curl-tests.png)

Description: This shows `/health`, an accepted order, and a rejected order where `qty > 100`.

### Evidence 5.5: Function App `VALIDATE_URL`

![Function validate url](docs/18-function-validate-url.png)

Description: This shows the Function App is configured to call the AKS validator.

### Evidence 5.6: AKS Idle Behavior

![AKS idle](docs/19-aks-idle.png)

Description: This shows the AKS node remains allocated even when no order is currently running.

## Task 6: ACI Report Job

### Evidence 6.1: Blob Container

![Reports container](docs/20-reports-container.png)

Description: This shows the `reports` container where PDFs are stored.

### Evidence 6.2: Manual ACI Run

![ACI show](docs/21-aci-show.png)

Description: This shows manual container instance `ci-report-test` reached `Succeeded`.

### Evidence 6.3: ACI Logs

![ACI logs](docs/22-aci-logs.png)

Description: This shows the report job generated and uploaded the PDF.

### Evidence 6.4: Generated PDF

![Test PDF blob](docs/23-test-pdf-blob.png)

Description: This shows `TEST-001.pdf` in Blob Storage.

### Evidence 6.5: Function App Managed Identity and IAM

![Managed identity IAM](docs/24-mi-iam.png)

Description: This shows the managed identity has the permissions needed to create ACIs and write blobs.

### Evidence 6.6: Report App Settings

![Report settings](docs/25-report-settings.png)

Description: This shows the report image, ACR, storage, subscription, and managed identity settings. Secrets are masked.

## Task 7: End-to-End Pipeline

### Evidence 7.1: Web App Wiring

![Web App function settings](docs/26-webapp-function-settings.png)

Description: This shows the frontend is wired to Function App `pa4-27100246-func`.

### Evidence 7.2: Happy Path UI

![UI before submit](docs/27-ui-before-submit.png)

![UI running](docs/28-ui-running.png)

![UI completed](docs/29-ui-completed-report.png)

Description: These screenshots show a valid order moving from submission to completed status with a report URL.

### Evidence 7.3: Backend Participation

![Backend evidence](docs/30-backend-evidence.png)

Description: This traces the same happy-path order through Function App, AKS validation, ACI report generation, and Blob Storage.

### Evidence 7.4: Reject Path UI

![UI rejected](docs/31-ui-rejected.png)

![No rejected ACI](docs/32-no-reject-aci.png)

Description: This shows an order with `qty > 100` is rejected and does not create a report ACI.

## Task 8: Write-up and Architecture Diagram

### Evidence 8.1: Architecture Diagram

![Architecture](docs/33-architecture.png)

Description: This shows GitHub, App Service, Durable Functions, AKS, ACI, Blob Storage, ACR, and managed identity/IAM.

### Question 8.2: Service Selection

App Service hosts the Node/Express web frontend because it provides a managed HTTP runtime and GitHub deployment integration with minimal server management. Durable Functions owns the long-running order workflow because it can start an orchestration, expose status URLs, and coordinate multiple async steps reliably. AKS hosts the validator because it demonstrates a continuously running containerized API behind a Kubernetes LoadBalancer. ACI runs the report job because each report is a short-lived one-shot container, so it does not need a permanently running worker.

### Question 8.3: ACI vs AKS

AKS keeps the cluster node allocated while idle, so it remains available but continues to incur node cost. ACI is job-oriented here: a container group starts for a report, exits after upload, and avoids maintaining a worker pool. Operationally, AKS requires Kubernetes objects such as deployments, services, pods, and image pull secrets, while ACI can be created directly by the Durable Function through the Azure SDK.

### Question 8.4: Durable Functions vs Plain HTTP

Durable Functions solves the status tracking problem by returning URLs that the frontend can poll while validation and report generation continue in the background. It also separates orchestration logic from activities, so retryable external work such as validator calls and ACI creation is not forced into one blocking HTTP request. A plain HTTP endpoint would be more likely to time out or lose progress visibility.

### Question 8.5: Cost Review

![Cost review](docs/34-cost-review.png)

Description: This Cost Management screenshot is scoped to `rg-sp26-27100246`. The AKS node is expected to be one of the more expensive resources because it remains allocated while the cluster exists.

### Question 8.6: Challenges Faced

One issue was that the Web App and Function App cannot share the same globally unique Azure name, so the Function App was named `pa4-27100246-func`. Another issue was the Function App storage connection: the subscription security policy can block the default `AzureWebJobsStorage` connection string, so the Function App was changed to use the existing user-assigned managed identity with `AzureWebJobsStorage__accountName`, `AzureWebJobsStorage__credential`, and `AzureWebJobsStorage__clientId`.
