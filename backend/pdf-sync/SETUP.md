# PDF Sync Backend Setup

## AWS Resources Needed

### 1. DynamoDB Table
- **Table name:** `memorize-sync`
- **Partition key:** `PK` (String)
- **Sort key:** `SK` (String)
- **TTL attribute:** `ttl` (enabled)

### 2. S3 Bucket
- **Bucket name:** `memorize-pdf-uploads`
- **CORS Configuration:**
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["PUT"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": [],
    "MaxAgeSeconds": 3600
  }
]
```
- **Lifecycle rule:** Delete objects after 7 days

### 3. Lambda Function
- **Runtime:** Node.js 20.x
- **Handler:** `index.handler`
- **Memory:** 128 MB
- **Timeout:** 30 seconds
- **Environment Variables:**
  - `DYNAMO_TABLE` = `memorize-sync`
  - `S3_BUCKET` = `memorize-pdf-uploads`
- **IAM Permissions:**
  - `dynamodb:PutItem`, `GetItem`, `Query`, `UpdateItem` on `memorize-sync`
  - `s3:PutObject`, `s3:GetObject` on `memorize-pdf-uploads/*`

### 4. API Gateway Routes
Add these routes to your existing API Gateway (`yp3pqak8l7`):

| Method | Path | Integration |
|--------|------|-------------|
| POST | /sync/register | Lambda |
| POST | /sync/validate | Lambda |
| POST | /sync/upload-url | Lambda |
| POST | /sync/confirm-upload | Lambda |
| GET | /sync/pending | Lambda |
| POST | /sync/ack | Lambda |
| OPTIONS | /sync/{proxy+} | Mock (CORS) |

**Enable CORS** on all routes.

### 5. Deploy Lambda
```bash
cd backend/pdf-sync
npm init -y
npm install @aws-sdk/client-dynamodb @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
zip -r function.zip index.mjs node_modules/
aws lambda create-function \
  --function-name memorize-pdf-sync \
  --runtime nodejs20.x \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::YOUR_ACCOUNT:role/YOUR_LAMBDA_ROLE \
  --environment Variables="{DYNAMO_TABLE=memorize-sync,S3_BUCKET=memorize-pdf-uploads}"
```

### 6. Deploy Website
```bash
# Host on S3 static website or any web server
aws s3 cp web/pdf-sync/index.html s3://your-website-bucket/index.html \
  --content-type text/html
```

Or simply open `web/pdf-sync/index.html` locally for testing.
