#!/usr/bin/env bash
# CS487 PA4 deploy helper for roll number 27100246.
# Run task by task:
#   chmod +x pa4-deploy.sh
#   ./pa4-deploy.sh task1
#   ./pa4-deploy.sh task2
#   ...

set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO." >&2' ERR

ROLLNUM="27100246"
REGION="ukwest"

RG="rg-sp26-${ROLLNUM}"
PLAN="pa4-${ROLLNUM}"
WEBAPP="pa4-${ROLLNUM}"
FUNCAPP="pa4-${ROLLNUM}-func"
STORAGE="pa4${ROLLNUM}"
ACR="pa4${ROLLNUM}"
AKS="pa4-${ROLLNUM}"
MI_NAME="mi-pa4-${ROLLNUM}"
BLOB_CONTAINER="reports"

ACR_SERVER="${ACR}.azurecr.io"
IMG_VALIDATE="${ACR_SERVER}/validate-api:v1"
IMG_REPORT="${ACR_SERVER}/report-job:v1"
IMG_FUNC="${ACR_SERVER}/func-app:v1"

info() { printf "\n[INFO] %s\n" "$*"; }
ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
shot() { printf "[SCREENSHOT] %s\n" "$*"; }

section() {
  printf "\n============================================================\n"
  printf "%s\n" "$*"
  printf "============================================================\n"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

preflight() {
  need_cmd az
  need_cmd docker
  need_cmd curl
  need_cmd python3
}

ensure_rg_storage_mi() {
  info "Ensuring resource group, storage account, and managed identity exist"

  az group create \
    --name "$RG" \
    --location "$REGION" \
    --output table

  if ! az storage account show --name "$STORAGE" --resource-group "$RG" >/dev/null 2>&1; then
    az storage account create \
      --name "$STORAGE" \
      --resource-group "$RG" \
      --location "$REGION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --allow-blob-public-access false \
      --output table
  else
    ok "Storage account already exists: $STORAGE"
  fi

  if ! az identity show --name "$MI_NAME" --resource-group "$RG" >/dev/null 2>&1; then
    az identity create \
      --name "$MI_NAME" \
      --resource-group "$RG" \
      --location "$REGION" \
      --output table
  else
    ok "Managed identity already exists: $MI_NAME"
  fi

  SUB_ID="$(az account show --query id -o tsv)"
  MI_PRINCIPAL_ID="$(az identity show --name "$MI_NAME" --resource-group "$RG" --query principalId -o tsv)"
  RG_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/${RG}"
  STORAGE_SCOPE="${RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STORAGE}"

  info "Ensuring managed identity has Contributor on the resource group"
  az role assignment create \
    --assignee-object-id "$MI_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role Contributor \
    --scope "$RG_SCOPE" \
    --output table 2>/dev/null || warn "Could not create Contributor role assignment. It may already exist or your account may not have roleAssignments/write."

  info "Ensuring managed identity has Storage Blob Data Contributor on storage"
  az role assignment create \
    --assignee-object-id "$MI_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_SCOPE" \
    --output table 2>/dev/null || warn "Could not create Storage Blob Data Contributor role assignment. It may already exist or your account may not have roleAssignments/write."
}

task1() {
  section "Task 1: App Service Web App"
  ensure_rg_storage_mi

  info "Creating Linux App Service plan: $PLAN"
  az appservice plan create \
    --name "$PLAN" \
    --resource-group "$RG" \
    --location "$REGION" \
    --sku B1 \
    --is-linux \
    --output table

  info "Creating Node Web App: $WEBAPP"
  az webapp create \
    --name "$WEBAPP" \
    --resource-group "$RG" \
    --plan "$PLAN" \
    --runtime "NODE:22-lts" \
    --output table

  info "Adding placeholder Function URLs to Web App settings"
  az webapp config appsettings set \
    --name "$WEBAPP" \
    --resource-group "$RG" \
    --settings \
      FUNCTION_START_URL="PLACEHOLDER_SET_IN_TASK7" \
      FUNCTION_STATUS_URL="PLACEHOLDER_SET_IN_TASK7" \
    --output table

  ok "Task 1 resources are ready."
  warn "Connect GitHub manually in Azure Portal: Web App -> Deployment Center -> your fork -> main."
  shot "docs/01-github-fork.png: your GitHub fork."
  shot "docs/02-webapp-overview.png: Web App overview for $WEBAPP."
  shot "docs/03-webapp-deployment-center.png: Deployment Center or successful GitHub Action."
  shot "docs/04-live-web-ui.png: https://${WEBAPP}.azurewebsites.net loaded in browser."
}

task2() {
  section "Task 2: ACR and Docker images"
  ensure_rg_storage_mi

  info "Creating ACR: $ACR"
  az acr create \
    --name "$ACR" \
    --resource-group "$RG" \
    --location "$REGION" \
    --sku Basic \
    --admin-enabled true \
    --output table

  info "Building images for linux/amd64"
  docker build --platform linux/amd64 -t validate-api:latest ./validate-api
  docker build --platform linux/amd64 -t report-job:latest ./report-job
  docker build --platform linux/amd64 -t func-app:latest ./function-app

  info "Local validator smoke test"
  docker rm -f validate-test >/dev/null 2>&1 || true
  docker run --rm -d --name validate-test -p 8080:8080 validate-api:latest
  sleep 3
  curl -s http://127.0.0.1:8080/health | python3 -m json.tool || true
  curl -s -X POST http://127.0.0.1:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"order_id":"LOCAL-1","items":[{"sku":"ABC","qty":2}]}' | python3 -m json.tool || true
  docker stop validate-test >/dev/null

  info "Pushing images to ACR"
  az acr login --name "$ACR"
  docker tag validate-api:latest "$IMG_VALIDATE"
  docker tag report-job:latest "$IMG_REPORT"
  docker tag func-app:latest "$IMG_FUNC"
  docker push "$IMG_VALIDATE"
  docker push "$IMG_REPORT"
  docker push "$IMG_FUNC"

  az acr repository list --name "$ACR" --output table
  ok "Task 2 complete."
  shot "docs/05-acr-overview.png: ACR overview for $ACR."
  shot "docs/06-docker-builds.png: terminal output showing successful builds."
  shot "docs/07-acr-repositories.png: ACR repositories showing validate-api, report-job, func-app."
}

task3() {
  section "Task 3: Durable Function code"
  python3 -m py_compile function-app/function_app.py
  ok "function-app/function_app.py compiles."
  warn "For the screenshot, run: cd function-app && func start"
  shot "docs/08-func-start-handlers.png: func start listing HTTP starter, orchestrator, and activities."
}

task4() {
  section "Task 4: Function App container deployment"
  ensure_rg_storage_mi

  info "Rebuilding and pushing Function image"
  docker build --platform linux/amd64 -t func-app:latest ./function-app
  az acr login --name "$ACR"
  docker tag func-app:latest "$IMG_FUNC"
  docker push "$IMG_FUNC"

  ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
  ACR_PASS="$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)"
  MI_CLIENT_ID="$(az identity show --name "$MI_NAME" --resource-group "$RG" --query clientId -o tsv)"
  MI_RESOURCE_ID="$(az identity show --name "$MI_NAME" --resource-group "$RG" --query id -o tsv)"
  SUB_ID="$(az account show --query id -o tsv)"

  if ! az functionapp show --name "$FUNCAPP" --resource-group "$RG" >/dev/null 2>&1; then
    info "Creating Function App: $FUNCAPP"
    az functionapp create \
      --name "$FUNCAPP" \
      --resource-group "$RG" \
      --plan "$PLAN" \
      --storage-account "$STORAGE" \
      --functions-version 4 \
      --runtime python \
      --runtime-version 3.11 \
      --deployment-container-image-name "$IMG_FUNC" \
      --docker-registry-server-url "https://${ACR_SERVER}" \
      --docker-registry-server-user "$ACR_USER" \
      --docker-registry-server-password "$ACR_PASS" \
      --assign-identity "$MI_RESOURCE_ID" \
      --output table
  else
    ok "Function App already exists: $FUNCAPP"
  fi

  info "Applying managed identity storage fix"
  az functionapp identity assign \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --identities "$MI_RESOURCE_ID" \
    --output table

  az functionapp config appsettings delete \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --setting-names AzureWebJobsStorage \
    --output table || true

  az functionapp config appsettings set \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --settings \
      "AzureWebJobsStorage__accountName=${STORAGE}" \
      "AzureWebJobsStorage__credential=managedidentity" \
      "AzureWebJobsStorage__clientId=${MI_CLIENT_ID}" \
      VALIDATE_URL="PLACEHOLDER_SET_IN_TASK5" \
      REPORT_IMAGE="${IMG_REPORT}" \
      ACR_SERVER="${ACR_SERVER}" \
      ACR_USERNAME="${ACR_USER}" \
      ACR_PASSWORD="${ACR_PASS}" \
      STORAGE_ACCOUNT_URL="https://${STORAGE}.blob.core.windows.net" \
      REPORT_RG="${RG}" \
      REPORT_LOCATION="${REGION}" \
      SUBSCRIPTION_ID="${SUB_ID}" \
      AZURE_CLIENT_ID="${MI_CLIENT_ID}" \
      FUNCTIONS_WORKER_RUNTIME="python" \
    --output table

  az functionapp restart --name "$FUNCAPP" --resource-group "$RG"
  info "Waiting for Function App restart"
  sleep 45

  FUNC_KEY="$(az functionapp function keys list \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --function-name http_starter \
    --query default -o tsv 2>/dev/null || true)"

  if [ -n "$FUNC_KEY" ]; then
    info "Starting orchestration smoke test. Failure is expected before Task 5 VALIDATE_URL wiring."
    RESP="$(curl -s -X POST \
      "https://${FUNCAPP}.azurewebsites.net/api/orchestrators/my_orchestrator?code=${FUNC_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"order_id":"SMOKE-001","items":[{"sku":"ABC","qty":2}]}')"
    echo "$RESP" | python3 -m json.tool || echo "$RESP"
    STATUS_URL="$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('statusQueryGetUri',''))" 2>/dev/null || true)"
    if [ -n "$STATUS_URL" ]; then
      sleep 10
      curl -s "$STATUS_URL" | python3 -m json.tool || true
    fi
  else
    warn "Function key was not ready yet. Retry the smoke test from the Azure Portal or CLI."
  fi

  ok "Task 4 complete."
  shot "docs/09-function-container-config.png: Function App container image config for $IMG_FUNC."
  shot "docs/10-function-identity-mi.png: user assigned identity $MI_NAME attached."
  shot "docs/11-function-storage-settings.png: three AzureWebJobsStorage__ settings."
  shot "docs/12-orchestration-start.png: curl start response with id and statusQueryGetUri."
  shot "docs/13-expected-failed-status.png: expected failure before VALIDATE_URL is configured."
}

task5() {
  section "Task 5: AKS validator"
  ensure_rg_storage_mi
  need_cmd kubectl

  if ! az aks show --resource-group "$RG" --name "$AKS" >/dev/null 2>&1; then
    az aks create \
      --resource-group "$RG" \
      --name "$AKS" \
      --node-count 1 \
      --node-vm-size Standard_B2s \
      --generate-ssh-keys \
      --output table
  else
    ok "AKS already exists: $AKS"
  fi

  az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing

  ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
  ACR_PASS="$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)"

  kubectl delete secret acr-secret --ignore-not-found
  kubectl create secret docker-registry acr-secret \
    --docker-server="$ACR_SERVER" \
    --docker-username="$ACR_USER" \
    --docker-password="$ACR_PASS"

  sed "s|pa4<rollnum>.azurecr.io|${ACR_SERVER}|g; s|<rollnum>|${ROLLNUM}|g" \
    validate-api/k8s/deployment.yaml > /tmp/validate-deployment.yaml

  kubectl apply -f /tmp/validate-deployment.yaml
  kubectl apply -f validate-api/k8s/service.yaml
  kubectl rollout status deployment/validate-deployment --timeout=3m

  info "Waiting for LoadBalancer external IP"
  EXT_IP=""
  for _ in $(seq 1 36); do
    EXT_IP="$(kubectl get service validate-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [ -n "$EXT_IP" ] && break
    sleep 5
  done

  if [ -z "$EXT_IP" ]; then
    echo "External IP not assigned yet. Run: kubectl get service validate-service" >&2
    exit 1
  fi

  VALIDATE_URL="http://${EXT_IP}:8080/validate"
  curl -s "http://${EXT_IP}:8080/health" | python3 -m json.tool || true
  curl -s -X POST "$VALIDATE_URL" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"O-1001","items":[{"sku":"ABC","qty":2}]}' | python3 -m json.tool || true
  curl -s -X POST "$VALIDATE_URL" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"O-1002","items":[{"sku":"ABC","qty":999}]}' | python3 -m json.tool || true

  az functionapp config appsettings set \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --settings VALIDATE_URL="$VALIDATE_URL" \
    --output table

  kubectl get nodes
  kubectl get pods
  kubectl get service validate-service
  ok "Task 5 complete. VALIDATE_URL=$VALIDATE_URL"
  shot "docs/14-aks-overview.png: AKS overview for $AKS."
  shot "docs/15-kubectl-nodes-pods.png: kubectl get nodes and kubectl get pods."
  shot "docs/16-kubectl-service.png: kubectl get service validate-service."
  shot "docs/17-validator-curl-tests.png: health, valid order, invalid order curl tests."
  shot "docs/18-function-validate-url.png: Function App VALIDATE_URL setting."
  shot "docs/19-aks-idle.png: AKS metrics or kubectl output after idle period."
}

task6() {
  section "Task 6: ACI report job"
  ensure_rg_storage_mi

  az storage container create \
    --account-name "$STORAGE" \
    --name "$BLOB_CONTAINER" \
    --auth-mode login \
    --output table || \
  az storage container create \
    --account-name "$STORAGE" \
    --name "$BLOB_CONTAINER" \
    --auth-mode key \
    --output table

  ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
  ACR_PASS="$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)"
  MI_CLIENT_ID="$(az identity show --name "$MI_NAME" --resource-group "$RG" --query clientId -o tsv)"
  MI_RESOURCE_ID="$(az identity show --name "$MI_NAME" --resource-group "$RG" --query id -o tsv)"
  SUB_ID="$(az account show --query id -o tsv)"
  STORAGE_URL="https://${STORAGE}.blob.core.windows.net"

  az container delete --resource-group "$RG" --name ci-report-test --yes >/dev/null 2>&1 || true

  az container create \
    --resource-group "$RG" \
    --name ci-report-test \
    --image "$IMG_REPORT" \
    --registry-login-server "$ACR_SERVER" \
    --registry-username "$ACR_USER" \
    --registry-password "$ACR_PASS" \
    --assign-identity "$MI_RESOURCE_ID" \
    --cpu 1 \
    --memory 1.5 \
    --restart-policy Never \
    --location "$REGION" \
    --environment-variables \
      ORDER_ID="TEST-001" \
      "ORDER_JSON={\"order_id\":\"TEST-001\",\"items\":[{\"sku\":\"ABC\",\"qty\":2}]}" \
      STORAGE_ACCOUNT_URL="$STORAGE_URL" \
      AZURE_CLIENT_ID="$MI_CLIENT_ID" \
    --output table

  info "Polling ci-report-test"
  for _ in $(seq 1 40); do
    STATE="$(az container show --resource-group "$RG" --name ci-report-test --query instanceView.state -o tsv 2>/dev/null || true)"
    echo "ci-report-test state: $STATE"
    [ "$STATE" = "Succeeded" ] && break
    [ "$STATE" = "Failed" ] && break
    sleep 10
  done

  az container show --resource-group "$RG" --name ci-report-test --query "{name:name,state:instanceView.state}" --output table
  az container logs --resource-group "$RG" --name ci-report-test || true
  az storage blob list \
    --account-name "$STORAGE" \
    --container-name "$BLOB_CONTAINER" \
    --auth-mode login \
    --output table || true

  az functionapp identity assign \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --identities "$MI_RESOURCE_ID" \
    --output table

  az functionapp config appsettings set \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --settings \
      REPORT_IMAGE="$IMG_REPORT" \
      ACR_SERVER="$ACR_SERVER" \
      ACR_USERNAME="$ACR_USER" \
      ACR_PASSWORD="$ACR_PASS" \
      STORAGE_ACCOUNT_URL="$STORAGE_URL" \
      REPORT_RG="$RG" \
      REPORT_LOCATION="$REGION" \
      SUBSCRIPTION_ID="$SUB_ID" \
      AZURE_CLIENT_ID="$MI_CLIENT_ID" \
    --output table

  ok "Task 6 complete."
  shot "docs/20-reports-container.png: Blob container reports."
  shot "docs/21-aci-show.png: ci-report-test state Succeeded."
  shot "docs/22-aci-logs.png: az container logs upload output."
  shot "docs/23-test-pdf-blob.png: TEST-001.pdf in Blob Storage."
  shot "docs/24-mi-iam.png: managed identity IAM role assignments."
  shot "docs/25-report-settings.png: Function App report settings, with secrets masked."
}

task7() {
  section "Task 7: End-to-end pipeline"

  FUNC_KEY="$(az functionapp function keys list \
    --name "$FUNCAPP" \
    --resource-group "$RG" \
    --function-name http_starter \
    --query default -o tsv)"

  FUNC_BASE="https://${FUNCAPP}.azurewebsites.net"
  START_URL="${FUNC_BASE}/api/orchestrators/my_orchestrator?code=${FUNC_KEY}"
  STATUS_PREFIX="${FUNC_BASE}/runtime/webhooks/durabletask/instances"

  az webapp config appsettings set \
    --name "$WEBAPP" \
    --resource-group "$RG" \
    --settings \
      FUNCTION_START_URL="$START_URL" \
      FUNCTION_STATUS_URL="$STATUS_PREFIX" \
    --output table

  info "Happy path direct backend test"
  HAPPY_RESP="$(curl -s -X POST "$START_URL" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"E2E-HAPPY-001","items":[{"sku":"ABC","qty":2}]}')"
  echo "$HAPPY_RESP" | python3 -m json.tool || echo "$HAPPY_RESP"
  HAPPY_STATUS_URL="$(echo "$HAPPY_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('statusQueryGetUri',''))" 2>/dev/null || true)"
  if [ -n "$HAPPY_STATUS_URL" ]; then
    for _ in $(seq 1 24); do
      POLL="$(curl -s "$HAPPY_STATUS_URL")"
      STATUS="$(echo "$POLL" | python3 -c "import json,sys; print(json.load(sys.stdin).get('runtimeStatus',''))" 2>/dev/null || true)"
      echo "happy runtimeStatus: $STATUS"
      if [ "$STATUS" = "Completed" ] || [ "$STATUS" = "Failed" ]; then
        echo "$POLL" | python3 -m json.tool || true
        break
      fi
      sleep 10
    done
  fi

  info "Reject path direct backend test"
  REJECT_RESP="$(curl -s -X POST "$START_URL" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"E2E-REJECT-001","items":[{"sku":"ABC","qty":999}]}')"
  echo "$REJECT_RESP" | python3 -m json.tool || echo "$REJECT_RESP"
  REJECT_STATUS_URL="$(echo "$REJECT_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('statusQueryGetUri',''))" 2>/dev/null || true)"
  if [ -n "$REJECT_STATUS_URL" ]; then
    sleep 10
    curl -s "$REJECT_STATUS_URL" | python3 -m json.tool || true
  fi

  az container list --resource-group "$RG" --output table || true
  ok "Task 7 backend wiring complete. Use the Web App UI for final screenshots."
  shot "docs/26-webapp-function-settings.png: Web App FUNCTION_START_URL and FUNCTION_STATUS_URL, with key masked."
  shot "docs/27-ui-before-submit.png: valid order before submit."
  shot "docs/28-ui-running.png: UI Running status."
  shot "docs/29-ui-completed-report.png: UI Completed status with report URL."
  shot "docs/30-backend-evidence.png: same order ID across Function, ACI, and Blob evidence."
  shot "docs/31-ui-rejected.png: invalid qty=999 order rejected."
  shot "docs/32-no-reject-aci.png: no report ACI for rejected order."
}

task8() {
  section "Task 8: Submission and cleanup notes"
  ok "Use SUBMISSION.md and docs/architecture.mmd as the starting point for the final submission."
  shot "docs/33-architecture.png: export or screenshot the architecture diagram."
  shot "docs/34-cost-review.png: Cost Management scoped to $RG."
  warn "After grading, delete costly resources, especially AKS:"
  echo "az aks delete --name $AKS --resource-group $RG --yes --no-wait"
}

all() {
  task1
  task2
  task3
  task4
  task5
  task6
  task7
  task8
}

preflight

case "${1:-help}" in
  task1) task1 ;;
  task2) task2 ;;
  task3) task3 ;;
  task4) task4 ;;
  task5) task5 ;;
  task6) task6 ;;
  task7) task7 ;;
  task8) task8 ;;
  all) all ;;
  *)
    echo "Usage: $0 [task1|task2|task3|task4|task5|task6|task7|task8|all]"
    exit 1
    ;;
esac
