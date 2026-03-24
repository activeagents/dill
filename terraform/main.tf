terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    porkbun = {
      source  = "marcfrederick/porkbun"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "porkbun" {
  api_key        = var.porkbun_api_key
  secret_api_key = var.porkbun_secret_key
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = var.app_name
  format        = "DOCKER"
  description   = "Docker repository for ${var.app_name}"

  depends_on = [google_project_service.apis]
}

# Store the Rails master key in Secret Manager
resource "google_secret_manager_secret" "rails_master_key" {
  secret_id = "${var.app_name}-rails-master-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "rails_master_key" {
  secret      = google_secret_manager_secret.rails_master_key.id
  secret_data = var.rails_master_key
}

# OAuth credentials - configure manually in GCP Console
# The OAuth client ID and secret should be set via gcloud or console
# and stored in Secret Manager as: dill-google-client-id, dill-google-client-secret

# Service account for Cloud Run
resource "google_service_account" "cloud_run" {
  account_id   = "${var.app_name}-run-sa"
  display_name = "${var.app_name} Cloud Run Service Account"
}

# Grant the service account access to read secrets
resource "google_secret_manager_secret_iam_member" "rails_master_key_access" {
  secret_id = google_secret_manager_secret.rails_master_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}

# OAuth secret access will be configured after OAuth is set up manually

# Cloud Run service
resource "google_cloud_run_v2_service" "app" {
  name     = var.app_name
  location = var.region

  template {
    service_account = google_service_account.cloud_run.email

    # Scale to zero when idle (free tier friendly)
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    # Keep costs at zero — use smallest resource allocation
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}/${var.app_name}:latest"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
        cpu_idle = true # CPU is only allocated during request processing
      }

      env {
        name  = "RAILS_ENV"
        value = "production"
      }

      env {
        name  = "DISABLE_SSL"
        value = "true" # Cloud Run handles SSL termination
      }

      env {
        name  = "RAILS_LOG_TO_STDOUT"
        value = "1"
      }

      env {
        name = "RAILS_MASTER_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.rails_master_key.secret_id
            version = "latest"
          }
        }
      }

      # Google OAuth SSO - will be configured after OAuth setup
      # Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET via gcloud run services update

      # Startup probe — Rails needs time to boot (thruster serves loading page meanwhile)
      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 18
        http_get {
          path = "/up"
          port = 8080
        }
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/up"
          port = 8080
        }
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.app,
    google_secret_manager_secret_version.rails_master_key,
  ]
}

# Make the Cloud Run service publicly accessible
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Optional: Custom domain mapping
resource "google_cloud_run_domain_mapping" "custom_domain" {
  count    = var.domain != "" ? 1 : 0
  location = var.region
  name     = var.domain

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name     = google_cloud_run_v2_service.app.name
    force_override = true
  }
}

# =============================================================================
# Porkbun DNS Configuration
# =============================================================================

locals {
  porkbun_configured = var.porkbun_api_key != "" && var.porkbun_secret_key != "" && var.domain != ""
}

# Google domain verification TXT record
resource "porkbun_dns_record" "google_verification" {
  count = local.porkbun_configured && var.google_site_verification != "" ? 1 : 0

  domain    = var.domain
  subdomain = ""
  type      = "TXT"
  content   = var.google_site_verification
  ttl       = 600
}
