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
variable "oauth_support_email" {
  description = "Support email for OAuth consent screen (must be a Google Workspace email)"
  type        = string
}

# Porkbun DNS Configuration
variable "porkbun_api_key" {
  description = "Porkbun API key for DNS management"
  type        = string
  sensitive   = true
  default     = ""
}

variable "porkbun_secret_key" {
  description = "Porkbun secret API key for DNS management"
  type        = string
  sensitive   = true
  default     = ""
}
