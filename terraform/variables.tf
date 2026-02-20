variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for deployment"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "dill"
}

variable "rails_master_key" {
  description = "Rails master key for decrypting credentials (from config/master.key)"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Custom domain for the application (optional, leave empty to use Cloud Run default URL)"
  type        = string
  default     = ""
}

# Google OAuth SSO Configuration
variable "google_client_id" {
  description = "Google OAuth2 client ID for SSO"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth2 client secret for SSO"
  type        = string
  sensitive   = true
}

variable "allowed_domains" {
  description = "Comma-separated list of allowed email domains for SSO (e.g., 'dill.vc,svsg.co')"
  type        = string
  default     = ""
}

variable "auto_provision_users" {
  description = "Whether to auto-create users from allowed domains on first login"
  type        = bool
  default     = false
}
