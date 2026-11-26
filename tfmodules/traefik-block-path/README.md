# Traefik block path

Stops some of a service's paths, usually its metrics endpoint, being reachable from outside the cluster. Requests to
them get a 403 from Traefik. Prometheus scrapes them inside the cluster, so it isn't affected.

It adds an IngressRoute for just those paths, with a higher priority than the service's own Ingress, and an
`ipAllowList` middleware that only allows `127.0.0.1`. It only uses Traefik's built-in features, so it doesn't depend
on a plugin being downloaded when Traefik starts (see issue #141). It only covers HTTPS: plain HTTP requests are
redirected to HTTPS by the service's own Ingress first.
