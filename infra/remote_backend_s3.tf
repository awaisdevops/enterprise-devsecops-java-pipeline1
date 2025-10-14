# Configure terraform remote backend using s3 bucket
terraform {
  backend "s3" {
    bucket = "dc-llc-tf-remote-state-bucket"
    key    = "dc-llc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}