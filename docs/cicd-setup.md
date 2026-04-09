# CI/CD Setup Guide

This document describes the CI/CD pipeline for Dill, including infrastructure provisioning and application deployment.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  GitHub Push    │────▶│  Terraform      │────▶│  Deploy         │
│  (terraform/*)  │     │  Plan/Apply     │     │  (auto-trigger) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                         │
┌─────────────────┐                                      │
│  GitHub Push    │──────────────────────────────────────┘
│  (app code)     │
└─────────────────┘

Infrastructure: Cloud SQL PostgreSQL + GCS + Secret Manager
Application: Cloud Run with auto-scaling
```

## Workflows

### 1. Terraform Workflow (`terraform.yml`)

**Triggers:**
- PR with changes to `terraform/**` → `terraform plan` (commented on PR)
- Push to `main` with changes to `terraform/**` → `terraform apply`

**Purpose:** Provisions and manages GCP infrastructure:
- Cloud SQL PostgreSQL instance
- GCS bucket for document storage
- Secret Manager secrets
- IAM bindings
- Cloud Run service configuration

### 2. Deploy Workflow (`deploy.yml`)

**Triggers:**
- PR (any code changes) → Deploy to staging
- Push to `main` → Deploy to production
- After Terraform workflow completes → Re-deploy to production

**Purpose:** Builds and deploys the Rails application to Cloud Run.

## Required GitHub Secrets

Configure these in: **Settings → Secrets and variables → Actions**

| Secret | Description | How to Get |
|--------|-------------|------------|
| `RAILS_MASTER_KEY` | Rails credential encryption key | `cat config/master.key` |
| `DB_PASSWORD` | PostgreSQL database password | Generate a secure password |
| `OAUTH_SUPPORT_EMAIL` | Google OAuth consent screen email | Your Google Workspace email |
| `GEMINI_API_KEY` | Google Gemini API key | [Google AI Studio](https://aistudio.google.com/) |
| `PORKBUN_API_KEY` | Porkbun DNS API key (optional) | [Porkbun API](https://porkbun.com/api/json/v3/documentation) |
| `PORKBUN_SECRET_KEY` | Porkbun DNS secret key (optional) | Same as above |

## Initial Setup (One-Time)

### 1. Bootstrap Terraform State Bucket

```bash
cd terraform
chmod +x bootstrap.sh
./bootstrap.sh
```

This creates a GCS bucket for Terraform state with:
- Versioning enabled
- GitHub Actions service account access

### 2. Configure GitHub Secrets

```bash
# Get your Rails master key
cat config/master.key

# Generate a secure database password
openssl rand -base64 32
```

Add all secrets to GitHub repository settings.

### 3. Initialize Terraform Locally (Optional)

```bash
cd terraform
terraform init
terraform plan \
  -var="project_id=dill-488620" \
  -var="rails_master_key=$(cat ../config/master.key)" \
  -var="db_password=YOUR_PASSWORD" \
  -var="oauth_support_email=you@example.com"
```

### 4. Push to Trigger CI/CD

```bash
git add .
git commit -m "feat: complete CI/CD setup"
git push origin main
```

The workflows will:
1. Run `terraform apply` (creates Cloud SQL, GCS, secrets)
2. After terraform completes, deploy the app to Cloud Run

## Environments

| Environment | URL | Trigger |
|-------------|-----|---------|
| Staging | Auto-generated Cloud Run URL | PR to main |
| Production | https://dill.vc | Push to main |

## Monitoring

### Check Workflow Status

```bash
# List recent runs
gh run list --limit 10

# Watch a specific run
gh run watch <run-id>

# View logs
gh run view <run-id> --log
```

### Check Infrastructure

```bash
# Cloud SQL status
gcloud sql instances describe dill-db

# Cloud Run status
gcloud run services describe dill --region us-central1

# GCS bucket
gcloud storage ls gs://dill-488620-dill-documents
```

## Troubleshooting

### Deploy fails with "secret not found"

Run terraform apply first to create the secrets:
```bash
cd terraform
terraform apply
```

### Database connection errors

Check Cloud SQL instance is running:
```bash
gcloud sql instances list
```

### Terraform state lock

If terraform is stuck, check for stale locks:
```bash
gcloud storage cat gs://dill-488620-tfstate/terraform/state/default.tflock
```

## Security Notes

- Terraform state contains sensitive data - bucket has versioning and IAM restrictions
- Database password is stored in Secret Manager, not in code
- Workload Identity Federation used - no long-lived service account keys
- All secrets accessed via Secret Manager at runtime
