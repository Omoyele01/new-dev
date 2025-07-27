terraform {
  backend "s3" {
    bucket         = "vgs-s3"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
