resource "random_id" "project_id" {
  byte_length = 4
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [
    module.project-authorized-compute,
    module.project-authorized-gcs,
    module.project-notauthorized-gcs

  ]

  create_duration = "30s"
}