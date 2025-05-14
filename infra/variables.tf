variable "GCP_PROJECT_ID" {
  description = "The GCP project ID"
  type        = string
}
variable "GCP_REGION" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}
variable "GCP_BUCKET_NAME" {
  description = "The name of the GCP bucket"
  type        = string
}
variable "GCP_BUCKET_LOCATION" {
  description = "The location of the GCP bucket"
  type        = string
  default     = "US"
}
variable "GCP_BUCKET_STORAGE_CLASS" {
  description = "The storage class of the GCP bucket"
  type        = string
  default     = "ARCHIVE"
}
variable "GCP_BUCKET_VERSIONING" {
  description = "Enable versioning for the GCP bucket"
  type        = bool
  default     = false
}
