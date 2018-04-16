terraform {
  backend "s3" {
    bucket = "testype"
    key    = "demotiad/frontgreen"
    region = "eu-west-1"
  }
}
