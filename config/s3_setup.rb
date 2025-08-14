#!/usr/bin/env ruby

# S3 Setup Helper Script
# This script helps you configure AWS S3 credentials for Active Storage

puts "🚀 Setting up Amazon S3 for Active Storage"
puts "=" * 50

puts "\n📋 Prerequisites:"
puts "1. AWS Account with S3 access"
puts "2. IAM user with S3 permissions"
puts "3. S3 bucket created"

puts "\n🔧 Required IAM Permissions:"
puts <<~PERMISSIONS
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket"
        ],
        "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
      }
    ]
  }
PERMISSIONS

puts "\n⚙️  Environment Variables to Set:"
puts "export AWS_REGION=ap-southeast-2"
puts "export S3_BUCKET=your-bucket-name"

puts "\n🔑 To set up credentials, run:"
puts "bin/rails credentials:edit"

puts "\nAdd this to your credentials file:"
puts <<~CREDENTIALS
  aws:
    access_key_id: your_access_key_here
    secret_access_key: your_secret_key_here
CREDENTIALS

puts "\n✅ Verify setup with:"
puts "bin/rails runner 'puts ActiveStorage::Blob.service.class'"
puts "Should output: ActiveStorage::Service::S3Service"

puts "\n🧪 Test S3 connection:"
puts "bin/rails runner \"puts ActiveStorage::Blob.service.bucket.exists?\""
