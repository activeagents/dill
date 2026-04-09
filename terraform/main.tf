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

  # Remote state in GCS - created by bootstrap.sh
  backend "gcs" {
    bucket = "dill-488620-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Porkbun provider for DNS management (optional)
# Uses placeholder values when not configured to avoid provider errors
provider "porkbun" {
  api_key        = var.porkbun_api_key != "" ? var.porkbun_api_key : "placeholder"
  secret_api_key = var.porkbun_secret_key != "" ? var.porkbun_secret_key : "placeholder"
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "generativelanguage.googleapis.com",  # Google Gemini API
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

# Store Gemini API key in Secret Manager (optional - only if provided)
resource "google_secret_manager_secret" "gemini_api_key" {
  count     = var.gemini_api_key != "" ? 1 : 0
  secret_id = "${var.app_name}-gemini-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "gemini_api_key" {
  count       = var.gemini_api_key != "" ? 1 : 0
  secret      = google_secret_manager_secret.gemini_api_key[0].id
  secret_data = var.gemini_api_key
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

# Grant access to Gemini API key secret (if configured)
resource "google_secret_manager_secret_iam_member" "gemini_api_key_access" {
  count     = var.gemini_api_key != "" ? 1 : 0
  secret_id = google_secret_manager_secret.gemini_api_key[0].id
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

    # Cloud SQL connection
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.main.connection_name]
      }
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

      # Mount Cloud SQL socket
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
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

      # Database URL for PostgreSQL via Cloud SQL socket
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      # GCS bucket for ActiveStorage
      env {
        name = "GCS_BUCKET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gcs_bucket.secret_id
            version = "latest"
          }
        }
      }

      # Note: GEMINI_API_KEY is set by deploy workflow via --set-secrets
      # The secret is created above in Secret Manager

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
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.gcs_bucket,
    google_sql_database_instance.main,
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

# =============================================================================
# Cloud SQL PostgreSQL (Production Database)
# =============================================================================

resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_sql_database_instance" "main" {
  name             = "${var.app_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_size         = 10
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled = true
      # For Cloud Run without VPC connector, we need public IP
      # In production with VPC, switch to private_network
      authorized_networks {
        name  = "cloud-run"
        value = "0.0.0.0/0"  # Cloud Run uses Cloud SQL Auth Proxy
      }
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = true

  depends_on = [google_project_service.sqladmin]
}

resource "google_sql_database" "app" {
  name     = var.app_name
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = var.app_name
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

# Store database URL in Secret Manager
resource "google_secret_manager_secret" "database_url" {
  secret_id = "${var.app_name}-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${google_sql_user.app.name}:${var.db_password}@/${google_sql_database.app.name}?host=/cloudsql/${google_sql_database_instance.main.connection_name}"
}

resource "google_secret_manager_secret_iam_member" "database_url_access" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Cloud Run service account access to Cloud SQL
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# =============================================================================
# Google Cloud Storage (Document Storage)
# =============================================================================

resource "google_storage_bucket" "documents" {
  name          = "${var.project_id}-${var.app_name}-documents"
  location      = var.storage_location
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST"]
    response_header = ["Content-Type", "Content-Disposition"]
    max_age_seconds = 3600
  }
}

# Grant Cloud Run service account access to GCS bucket
resource "google_storage_bucket_iam_member" "documents_access" {
  bucket = google_storage_bucket.documents.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Store bucket name in Secret Manager for consistency
resource "google_secret_manager_secret" "gcs_bucket" {
  secret_id = "${var.app_name}-gcs-bucket"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "gcs_bucket" {
  secret      = google_secret_manager_secret.gcs_bucket.id
  secret_data = google_storage_bucket.documents.name
}

resource "google_secret_manager_secret_iam_member" "gcs_bucket_access" {
  secret_id = google_secret_manager_secret.gcs_bucket.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}
