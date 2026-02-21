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

output "oauth_client_id" {
  description = "The Google OAuth client ID (auto-generated)"
  value       = google_iap_client.app.client_id
}

output "oauth_callback_url" {
  description = "The OAuth callback URL to configure in Google Cloud Console"
  value       = var.domain != "" ? "https://${var.domain}/auth/google_oauth2/callback" : "${google_cloud_run_v2_service.app.uri}/auth/google_oauth2/callback"
}
