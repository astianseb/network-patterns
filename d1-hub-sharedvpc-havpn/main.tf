resource "random_id" "project_id" {
  byte_length = 4
}

resource "time_sleep" "wait_30_seconds" {
  # depends_on = [
  #   module.project_hub,
  #   module.project_host
  # ]

  create_duration = "30s"
}