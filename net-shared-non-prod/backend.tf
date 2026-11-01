terraform {
  # The bucket is passed with -backend-config="bucket=..." by the workflows.
  backend "gcs" {
    prefix = "terraform/state/net-shared-non-prod"
  }
}
