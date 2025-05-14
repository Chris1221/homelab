provider "google" {
  project = var.GCP_PROJECT_ID
  region  = var.GCP_REGION
}

module "service_accounts" {
  source                    = "./modules/service_accounts"
  restic_backup_bucket_name = google_storage_bucket.restic_backup.name
}

resource "google_storage_bucket" "restic_backup" {
  name          = var.GCP_BUCKET_NAME
  location      = var.GCP_BUCKET_LOCATION
  storage_class = var.GCP_BUCKET_STORAGE_CLASS

  versioning {
    enabled = var.GCP_BUCKET_VERSIONING
  }

  uniform_bucket_level_access = true
}
