output "service_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = var.domain != "" ? "https://${var.domain}" : google_cloud_run_v2_service.app.uri
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository URL for pushing Docker images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}"
}

output "docker_image_tag" {
  description = "The full Docker image tag to use when pushing"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}/${var.app_name}:latest"
}

# OAuth client ID will be configured manually

output "oauth_callback_url" {
  description = "The OAuth callback URL to configure in Google Cloud Console"
  value       = var.domain != "" ? "https://${var.domain}/auth/google_oauth2/callback" : "${google_cloud_run_v2_service.app.uri}/auth/google_oauth2/callback"
}

# Database outputs
output "database_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "database_connection_name" {
  description = "Cloud SQL connection name for Cloud Run"
  value       = google_sql_database_instance.main.connection_name
}

# Storage outputs
output "gcs_bucket_name" {
  description = "GCS bucket name for document storage"
  value       = google_storage_bucket.documents.name
}

output "gcs_bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.documents.url
}
