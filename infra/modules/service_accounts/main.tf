# Add a service account for restic with the necessary permissions
resource "google_service_account" "restic" {
  account_id   = "restic"
  display_name = "Restic Backup Service Account"
}
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
