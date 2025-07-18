terraform {
  backend "s3" {
    bucket         = "state-s3-1752553507"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}