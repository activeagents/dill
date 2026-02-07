#!/usr/bin/env bash
set -euo pipefail

# Deploy Dill to GCP Cloud Run
#
# Prerequisites:
#   - gcloud CLI installed and authenticated (gcloud auth login)
#   - Docker installed
#   - Terraform installed
#   - A GCP project with billing enabled (free tier is sufficient)
#
# Usage:
#   cd terraform
#   ./deploy.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"

# Load terraform variables
if [ ! -f "$SCRIPT_DIR/terraform.tfvars" ]; then
  echo "Error: terraform/terraform.tfvars not found."
  echo "Copy terraform.tfvars.example to terraform.tfvars and fill in your values."
  exit 1
fi

# Parse project_id and region from tfvars
PROJECT_ID=$(grep 'project_id' "$SCRIPT_DIR/terraform.tfvars" | sed 's/.*= *"\(.*\)"/\1/')
REGION=$(grep 'region' "$SCRIPT_DIR/terraform.tfvars" | sed 's/.*= *"\(.*\)"/\1/')
APP_NAME=$(grep 'app_name' "$SCRIPT_DIR/terraform.tfvars" | sed 's/.*= *"\(.*\)"/\1/' || echo "dill")

if [ -z "$APP_NAME" ] || [ "$APP_NAME" = "dill" ]; then
  APP_NAME="dill"
fi

DOCKER_TAG="${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}/${APP_NAME}:latest"

echo "==> Deploying ${APP_NAME} to GCP Cloud Run"
echo "    Project:  ${PROJECT_ID}"
echo "    Region:   ${REGION}"
echo "    Image:    ${DOCKER_TAG}"
echo ""

# Step 1: Provision infrastructure with Terraform
echo "==> Step 1: Running Terraform to provision infrastructure..."
cd "$SCRIPT_DIR"
terraform init
terraform apply -auto-approve
cd "$APP_DIR"

# Step 2: Configure Docker to push to Artifact Registry
echo ""
echo "==> Step 2: Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Step 3: Build the Docker image
echo ""
echo "==> Step 3: Building Docker image..."
docker build -t "$DOCKER_TAG" "$APP_DIR"

# Step 4: Push the image to Artifact Registry
echo ""
echo "==> Step 4: Pushing image to Artifact Registry..."
docker push "$DOCKER_TAG"

# Step 5: Deploy to Cloud Run (update the service to use the new image)
echo ""
echo "==> Step 5: Deploying new image to Cloud Run..."
gcloud run services update "$APP_NAME" \
  --region "$REGION" \
  --image "$DOCKER_TAG" \
  --project "$PROJECT_ID" \
  --quiet

# Print the service URL
echo ""
echo "==> Deployment complete!"
SERVICE_URL=$(gcloud run services describe "$APP_NAME" --region "$REGION" --project "$PROJECT_ID" --format='value(status.url)')
echo "    Application URL: ${SERVICE_URL}"
