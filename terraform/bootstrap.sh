#!/bin/bash
# Bootstrap script to create Terraform state bucket
# Run this ONCE before using Terraform with GCS backend
#
# Usage: ./bootstrap.sh

set -euo pipefail

PROJECT_ID="dill-488620"
REGION="us-central1"
BUCKET_NAME="${PROJECT_ID}-tfstate"

echo "==> Creating Terraform state bucket: ${BUCKET_NAME}"

# Create the bucket if it doesn't exist
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access \
    --public-access-prevention

  echo "==> Bucket created successfully"
else
  echo "==> Bucket already exists"
fi

# Enable versioning for state file protection
gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

echo "==> Versioning enabled"

# Grant the GitHub Actions service account access
SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Granting access to ${SA_EMAIL}"
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

echo ""
echo "==> Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Run: cd terraform && terraform init"
echo "  2. Run: terraform plan"
echo "  3. Push to GitHub - CI/CD will handle the rest"
