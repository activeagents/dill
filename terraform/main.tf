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

# OAuth Brand (Consent Screen)
resource "google_iap_brand" "app" {
  support_email     = var.oauth_support_email
  application_title = "Dill"
  project           = var.project_id

  depends_on = [google_project_service.apis]
}

# OAuth Client
resource "google_iap_client" "app" {
  display_name = "Dill Web App"
  brand        = google_iap_brand.app.name
}

# Store Google OAuth client secret in Secret Manager
resource "google_secret_manager_secret" "google_client_secret" {
  secret_id = "${var.app_name}-google-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "google_client_secret" {
  secret      = google_secret_manager_secret.google_client_secret.id
  secret_data = google_iap_client.app.secret
}

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

resource "google_secret_manager_secret_iam_member" "google_client_secret_access" {
  secret_id = google_secret_manager_secret.google_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}

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
        container_port = 80
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

      # Google OAuth SSO configuration
      env {
        name  = "GOOGLE_CLIENT_ID"
        value = google_iap_client.app.client_id
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "ALLOWED_DOMAINS"
        value = var.allowed_domains
      }

      env {
        name  = "AUTO_PROVISION_USERS"
        value = var.auto_provision_users ? "true" : "false"
      }

      # Startup probe — Rails needs time to boot (thruster serves loading page meanwhile)
      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 18
        http_get {
          path = "/up"
        }
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/up"
        }
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.app,
    google_secret_manager_secret_version.rails_master_key,
    google_secret_manager_secret_version.google_client_secret,
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
    route_name = google_cloud_run_v2_service.app.name
  }
}

# =============================================================================
# Porkbun DNS Configuration (only created when domain and API keys are set)
# =============================================================================

locals {
  # Google Cloud Run load balancer IPs
  cloud_run_ips = [
    "216.239.32.21",
    "216.239.34.21",
    "216.239.36.21",
    "216.239.38.21",
  ]

  # Check if Porkbun is configured
  porkbun_configured = var.porkbun_api_key != "" && var.porkbun_secret_key != "" && var.domain != ""
}

# A records for apex domain (dill.vc)
resource "porkbun_dns_record" "apex_a" {
  for_each = local.porkbun_configured ? toset(local.cloud_run_ips) : []

  domain    = var.domain
  subdomain = ""
  type      = "A"
  content   = each.value
  ttl       = 600
}

# CNAME record for www subdomain
resource "porkbun_dns_record" "www_cname" {
  count = local.porkbun_configured ? 1 : 0

  domain    = var.domain
  subdomain = "www"
  type      = "CNAME"
  content   = "ghs.googlehosted.com"
  ttl       = 600
}
