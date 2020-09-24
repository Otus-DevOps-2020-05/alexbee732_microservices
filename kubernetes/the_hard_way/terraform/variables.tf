variable cloud_id {
  description = "Cloud"
}
variable folder_id {
  description = "Folder"
}
variable zone {
  description = "Zone"
  default     = "ru-central1-a"
}
variable service_account_key_file {
  description = "terraform service account key .json"
}
variable public_key_path {
  description = "public key path"
}
variable private_key_path {
  description = "private key path"
}
variable masters_count {
  description = "number of master nodes"
}
variable workers_count {
  description = "number of workers nodes"
}
