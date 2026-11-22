# Here rather than in platform because platform creates SecretStores and ExternalSecrets with kubernetes_manifest, which
# needs the CRDs to exist when platform is planned (see ADR 002)
module "external_secrets" {
  source = "../external-secrets"

  depends_on = [helm_release.prometheus_operator_crds]
}
