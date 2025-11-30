# AWS S3 Bucket for AppSpec file
resource "aws_s3_bucket" "appspec_bucket" {
  bucket = "tai-appspec-bucket" 

  tags = {
    Name = "AppSpecBuckett"
  }
}


