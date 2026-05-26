---
name: torch:upload-artifact
description: Upload an HTML file to the internal artifacts S3 bucket and return a shareable URL
argument-hint: "<file-path> [s3-key]"
---

# Upload Artifact

Upload an HTML artifact to the `torch-internal-artifacts` S3 bucket (behind Cognito SSO, @torch.io only) and return the shareable URL.

## Configuration

- **S3 Bucket**: `torch-internal-artifacts`
- **AWS Profile**: `torch-cognito`
- **CloudFront Domain**: `d6k0bi38kbaeg.cloudfront.net`

## Steps

### 1. Parse arguments

The user provides `$ARGUMENTS` which should contain:
- **file-path** (required): path to the HTML file to upload
- **s3-key** (optional): custom S3 key/path. If not provided, use the filename.

### 2. Validate the file

- Confirm the file exists
- Confirm it's an HTML file (`.html` extension)

### 3. Upload to S3

```bash
aws s3 cp <file-path> s3://torch-internal-artifacts/<s3-key> \
  --content-type "text/html" \
  --profile torch-cognito
```

If the file references local CSS/JS/images, warn the user those won't be available unless also uploaded or inlined.

### 4. Return the URL

Print the fully qualified shareable URL:

```
https://d6k0bi38kbaeg.cloudfront.net/<s3-key>
```

Remind the user: recipients need a @torch.io Google account to access.
