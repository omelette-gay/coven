locals {
  endpoint = "http://${var.name}-rustfs-svc.${var.namespace}.svc.cluster.local:9000"

  # renovate: datasource=docker depName=rustfs/rc
  rc_image_tag = "v0.1.38"

  public_buckets = var.public_api == null ? toset([]) : var.public_api.buckets

  # Lets browsers on these origins use presigned URLs. RustFS only sends CORS headers for buckets with rules, so other
  # buckets, and other origins, are refused by the browser
  cors_xml = var.public_api == null ? null : join("", concat(
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
      contains(local.public_buckets, bucket) ? [
        "cat > /tmp/cors.xml <<'XML'",
        local.cors_xml,
        "XML",
        "rc bucket cors set object-store/${bucket} /tmp/cors.xml",
      ] : [],
      [""],
    ))
  }
}
