# Add a service account for restic with the necessary permissions
resource "google_service_account" "restic" {
  account_id   = "restic"
  display_name = "Restic Backup Service Account"
}

# NOTE: The JSON key for this service account is deliberately NOT managed here.
# Terraform state is not an acceptable home for a long-lived credential, so the
# key is created once out-of-band and stored in 1Password (item "backrest-sa-key"
# in the "homelab" vault). See scripts/push_sa_key.sh / scripts/restore_sa_key.sh
# and the "Secret management" section of the README.
resource "google_storage_bucket_iam_member" "restic_backup" {
  bucket = var.restic_backup_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.restic.email}"
}
resource "google_storage_bucket_iam_member" "restic_backup_viewer" {
  bucket = var.restic_backup_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.restic.email}"
}
resource "google_storage_bucket_iam_member" "restic_backup_admin" {
  bucket = var.restic_backup_bucket_name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.restic.email}"
}
resource "google_storage_bucket_iam_member" "restic_backup_editor" {
  bucket = var.restic_backup_bucket_name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.restic.email}"
}
resource "google_storage_bucket_iam_member" "restic_backup_owner" {
  bucket = var.restic_backup_bucket_name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.restic.email}"
}
