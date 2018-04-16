terraform {
  backend "s3" {
    bucket = "testype"
    key    = "demotiad/frontblue"
    region = "eu-west-1"
  }
}
