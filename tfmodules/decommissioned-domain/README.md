# Decommissioned domain

Permanently redirects every request to a retired domain's hostnames to a new URL, using a Traefik middleware, with a
TLS certificate for each hostname so HTTPS links keep working. Each domain gets its own namespace. DNS records come
from external-dns, which reads the Ingresses.
