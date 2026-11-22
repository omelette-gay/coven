# Vault's certificate authority, which cert-manager's `vault` ClusterIssuer issues certificates from: every certificate
# on the testlab, and on coven only the MariaDB operator's webhook certificate.
resource "vault_mount" "pki" {
  path                  = "pki"
  type                  = "pki"
  max_lease_ttl_seconds = 87600 * 60 * 60
}

# The private key never leaves Vault (an "internal" root), so only the certificate is in Terraform state. This replaced
# the root Ansible made in November 2026, which is still in the mount as a second issuer until it's deleted by hand.
resource "vault_pki_secret_backend_root_cert" "cluster" {
  backend     = vault_mount.pki.path
  type        = "internal"
  common_name = var.cluster_domain
  ttl         = 87600 * 60 * 60
  issuer_name = "cluster"
}

resource "vault_pki_secret_backend_config_issuers" "pki" {
  backend = vault_mount.pki.path
  default = vault_pki_secret_backend_root_cert.cluster.issuer_id
}

resource "vault_pki_secret_backend_config_urls" "pki" {
  backend                 = vault_mount.pki.path
  issuing_certificates    = ["http://vault.vault.svc.cluster.local:8200/v1/pki/ca"]
  crl_distribution_points = ["http://vault.vault.svc.cluster.local:8200/v1/pki/crl"]
}

resource "vault_pki_secret_backend_role" "coven" {
  backend        = vault_mount.pki.path
  name           = "coven"
  allow_any_name = true
  require_cn     = false
  max_ttl        = 8760 * 60 * 60
}

resource "vault_policy" "pki_issuer" {
  name = "pki-${vault_pki_secret_backend_role.coven.name}-issuer"

  policy = chomp(<<-EOT
    path "pki*" { capabilities = ["read", "list"] }
    path "pki/sign/${vault_pki_secret_backend_role.coven.name}" { capabilities = ["create", "update"] }
    path "pki/issue/${vault_pki_secret_backend_role.coven.name}" { capabilities = ["create"] }
  EOT
  )
}

resource "vault_kubernetes_auth_backend_role" "cert_manager" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "cert-manager"
  bound_service_account_names      = [kubernetes_service_account_v1.vault_issuer.metadata[0].name]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = [vault_policy.pki_issuer.name]
}

# The service account cert-manager logs in to Vault as. cert-manager requests tokens for it, so it needs no token of its
# own mounted anywhere.
resource "kubernetes_service_account_v1" "vault_issuer" {
  metadata {
    name      = "vault-issuer"
    namespace = "cert-manager"
  }

  automount_service_account_token = false
}

resource "kubernetes_role_v1" "vault_issuer" {
  metadata {
    name      = "vault-issuer"
    namespace = "cert-manager"
  }

  rule {
    api_groups     = [""]
    resources      = ["serviceaccounts/token"]
    resource_names = [kubernetes_service_account_v1.vault_issuer.metadata[0].name]
    verbs          = ["create"]
  }
}

resource "kubernetes_role_binding_v1" "vault_issuer" {
  metadata {
    name      = "vault-issuer"
    namespace = "cert-manager"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    namespace = "cert-manager"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.vault_issuer.metadata[0].name
  }
}

resource "kubernetes_manifest" "vault_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault"
    }
    spec = {
      vault = {
        server = "http://vault.vault.svc.cluster.local:8200"
        path   = "pki/sign/${vault_pki_secret_backend_role.coven.name}"
        auth = {
          kubernetes = {
            role      = vault_kubernetes_auth_backend_role.cert_manager.role_name
            mountPath = "/v1/auth/${vault_auth_backend.kubernetes.path}"
            serviceAccountRef = {
              name = kubernetes_service_account_v1.vault_issuer.metadata[0].name
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_role_binding_v1.vault_issuer, vault_pki_secret_backend_config_issuers.pki]
}
