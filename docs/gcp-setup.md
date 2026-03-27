# GCP Cloud Run Setup Guide

This guide walks you through setting up Google Cloud Platform for Dill deployments.

## Prerequisites

- Google Cloud SDK (`gcloud`) installed
- A Google account with billing enabled
- GitHub repository access

## 1. Create GCP Project

```bash
# Login to GCP
gcloud auth login

# Create a new project (replace with your project ID)
gcloud projects create dill-vc-prod --name="Dill Production"

# Set it as the active project
gcloud config set project dill-vc-prod

# Link billing account (required for Cloud Run)
gcloud billing accounts list
'cloud billing projects link dill-vc-prod --billing-account=YOUR_BILLING_ACCOUNT_ID

```

## 2. Enable Required APIs

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com
```

## 3. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create dill \
  --location=us-central1 \
  --repository-format=docker \
  --description="Dill Docker images"
```

## 4. Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# Grant required roles
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"

# Cloud Run Admin
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

# Service Account User (required for deploying)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# Artifact Registry Writer
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

# Secret Manager Accessor
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.accessor"

# Create and download JSON key
gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=${SA_EMAIL}

echo "Key saved to gcp-key.json - add this to GitHub Secrets as GCP_SA_KEY"
```

## 5. Create Secrets in Secret Manager

```bash
# Generate and store Rails secret key
SECRET_KEY=$(openssl rand -hex 64)
echo -n "${SECRET_KEY}" | gcloud secrets create SECRET_KEY_BASE --data-file=-

# Store database URL (replace with your actual connection string)
# For Cloud SQL PostgreSQL:
# postgresql://user:pass@/dill_production?host=/cloudsql/PROJECT:REGION:INSTANCE
echo -n "sqlite3:///rails/storage/production.sqlite3" | gcloud secrets create DATABASE_URL --data-file=-
```

## 5a. Set Up Google Gemini API (AI Features)

The application uses Google's Gemini API for AI-powered features. Here's how to set it up:

### Enable the Generative Language API

```bash
gcloud services enable generativelanguage.googleapis.com
```

### Get a Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click "Create API key"
3. Select your GCP project or create a new one
4. Copy the generated API key

### Store the API Key in Secret Manager

```bash
# Store your Gemini API key (replace YOUR_GEMINI_API_KEY with actual key)
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create dill-gemini-api-key --data-file=-

# Grant the Cloud Run service account access
PROJECT_ID=$(gcloud config get-value project)
gcloud secrets add-iam-policy-binding dill-gemini-api-key \
  --member="serviceAccount:dill-run-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Update Cloud Run with the API Key

If using Terraform, add the `gemini_api_key` variable to your `terraform.tfvars`:

```hcl
gemini_api_key = "your-api-key-here"
```

Or set it manually via gcloud:

```bash
gcloud run services update dill \
  --region us-central1 \
  --set-secrets="GEMINI_API_KEY=dill-gemini-api-key:latest"
```

### Available Models

The Gemini provider supports these models:
- `gemini-2.0-flash` (default, fast and capable)
- `gemini-2.0-flash-lite` (even faster, lower cost)
- `gemini-1.5-pro` (more capable for complex tasks)
- `gemini-1.5-flash` (balanced speed and capability)

Configure in `config/active_agent.yml`:

```yaml
production:
  gemini:
    service: "Gemini"
    api_key: <%= ENV['GEMINI_API_KEY'] %>
    model: "gemini-2.0-flash"
    temperature: 0.7
```

### Using Gemini in Agents

To use Gemini in an agent:

```ruby
class MyAgent < ApplicationAgent
  generate_with :gemini, model: "gemini-2.0-flash"

  def analyze
    @content = params[:content]
    prompt
  end
end
```

## 6. Configure GitHub Secrets

Add these secrets to your GitHub repository:

1. `GCP_PROJECT_ID` - Your GCP project ID (e.g., `dill-vc-prod`)
2. `GCP_SA_KEY` - The contents of `gcp-key.json`

Go to: **Repository → Settings → Secrets and variables → Actions**

## 7. Test Local Deployment

```bash
# Build Docker image locally
docker build -t dill:latest .

# Tag for Artifact Registry
docker tag dill:latest us-central1-docker.pkg.dev/${PROJECT_ID}/dill/app:latest

# Push to Artifact Registry
docker push us-central1-docker.pkg.dev/${PROJECT_ID}/dill/app:latest

# Deploy to Cloud Run
gcloud run deploy dill \
  --image us-central1-docker.pkg.dev/${PROJECT_ID}/dill/app:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated
```

## 8. Set Up Custom Domain (Optional)

```bash
# Map the domain to Cloud Run
gcloud run domain-mappings create --service dill --domain dill.vc --region us-central1
```

Follow the output instructions to add DNS records to your domain.

## Environment Overview

| Environment | Trigger | URL |
|-------------|---------|-----|
| Staging | PR created/updated | `https://dill-staging-*.run.app` |
| Production | Merge to main | `https://dill.vc` |

## Troubleshooting

### View Logs
```bash
gcloud run logs read dill --region us-central1
```

### Check Service Status
```bash
gcloud run services describe dill --region us-central1
```

### Rollback
```bash
gcloud run services update-traffic dill \
  --to-revisions PREVIOUS_REVISION_NAME=100 \
  --region us-central1
```
