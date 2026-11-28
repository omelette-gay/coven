locals {
  endpoint = "http://${var.name}-rustfs-svc.${var.namespace}.svc.cluster.local:9000"

  # renovate: datasource=docker depName=rustfs/rc
  rc_image_tag = "v0.1.38"

  public_buckets      = var.public_api == null ? toset([]) : var.public_api.buckets
  public_read_buckets = var.public_api == null ? toset([]) : var.public_api.public_read_buckets
  cors_buckets        = var.public_api == null ? toset([]) : (length(var.public_api.cors_allowed_origins) > 0 ? var.public_api.buckets : toset([]))

  # Lets browsers on these origins use presigned URLs. RustFS only sends CORS headers for buckets with rules, so other
  # buckets, and other origins, are refused by the browser
  cors_xml = length(local.cors_buckets) == 0 ? null : join("", concat(
    ["<CORSConfiguration><CORSRule>"],
    [for origin in var.public_api.cors_allowed_origins : "<AllowedOrigin>${origin}</AllowedOrigin>"],
    [for method in ["GET", "HEAD", "PUT", "POST"] : "<AllowedMethod>${method}</AllowedMethod>"],
    ["<AllowedHeader>*</AllowedHeader><ExposeHeader>ETag</ExposeHeader><MaxAgeSeconds>3600</MaxAgeSeconds>"],
    ["</CORSRule></CORSConfiguration>"],
  ))

  # The script each bucket's Job runs. Buckets without versioning or CORS get exactly the script they always have, so
  # adding these options doesn't replace existing stores' Jobs
  bucket_scripts = {
    for bucket in var.buckets : bucket => join("\n", concat(
      [
        "set -eu",
        "rc alias set object-store ${local.endpoint} \"$RUSTFS_ACCESS_KEY\" \"$RUSTFS_SECRET_KEY\"",
        "rc bucket create object-store/${bucket} --ignore-existing",
      ],
      contains(var.versioned_buckets, bucket) ? ["rc bucket version enable object-store/${bucket}"] : [],
      contains(local.cors_buckets, bucket) ? [
        "cat > /tmp/cors.xml <<'XML'",
        local.cors_xml,
        "XML",
        "rc bucket cors set object-store/${bucket} /tmp/cors.xml",
      ] : [],
      # Anyone can fetch an object by its key, but not list the bucket. RustFS's `download` permission would also allow
      # listing, so this sets a policy with only s3:GetObject
      contains(local.public_read_buckets, bucket) ? [
        "cat > /tmp/policy.json <<'JSON'",
        jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect    = "Allow"
            Principal = "*"
            Action    = ["s3:GetObject"]
            Resource  = ["arn:aws:s3:::${bucket}/*"]
          }]
        }),
        "JSON",
        "rc bucket anonymous set-json /tmp/policy.json object-store/${bucket}",
      ] : [],
      # Other public buckets only take signed requests, which also undoes public_read_buckets if a bucket is taken out
      contains(local.public_buckets, bucket) && !contains(local.public_read_buckets, bucket) ? [
        "rc bucket anonymous set private object-store/${bucket}",
      ] : [],
      [""],
    ))
  }
}
