resource "aws_s3_bucket" "logging" {
  bucket = "examplebuckettftest"
  acl    = "private"
  versioning {
    enabled    = true
  }
}
