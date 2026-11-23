# Vault's configuration. Vault itself is installed by bootstrap, and initialised and unsealed by hand.

# Where every secret lives. Losing it would lose them all, so Terraform refuses to destroy it.
resource "vault_mount" "secret" {
  path    = "secret"
  type    = "kv"
  options = { version = "2" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_policy" "admin" {
  name = "admin"

  policy = chomp(<<-EOT
    path "*" {
      capabilities = ["sudo", "read", "create", "update", "delete", "list", "patch"]
    }
  EOT
  )
}

# lets pods pull private images from GHCR (see the app-namespace module)
resource "vault_policy" "ghcr_creds_read" {
  name = "ghcr-creds-read"

  policy = chomp(<<-EOT
    path "${vault_mount.secret.path}/data/repositories/ghcr" {
      capabilities = ["read"]
    }
  EOT
  )
}

# The cluster's CA, so Vault can talk to the Kubernetes API
data "kubernetes_config_map_v1" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

# Lets Kubernetes service accounts log in to Vault, e.g. External Secrets Operator syncing a secret
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.kubernetes_api_url
  kubernetes_ca_cert = data.kubernetes_config_map_v1.kube_root_ca.data["ca.crt"]
}

# Lets Vault issue short-lived Kubernetes credentials: `./login.sh` for people, and GitHub Actions
resource "kubernetes_cluster_role_v1" "vault_credential_issuing" {
  metadata {
    name = "allow-vault-credential-issuing"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "serviceaccounts/token"]
    verbs      = ["create", "update", "delete"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "clusterrolebindings"]
    verbs      = ["create", "update", "delete"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "clusterroles"]
    verbs      = ["bind", "escalate", "create", "update", "delete"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "vault_credential_issuing" {
  metadata {
    name = "allow-vault-credential-issuing"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.vault_credential_issuing.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = var.namespaces.vault
  }
}

resource "vault_kubernetes_secret_backend" "kubernetes" {
  path               = "kubernetes"
  kubernetes_host    = var.kubernetes_api_url
  kubernetes_ca_cert = data.kubernetes_config_map_v1.kube_root_ca.data["ca.crt"]
}

# Used by `./login.sh`
resource "vault_kubernetes_secret_backend_role" "admin" {
  backend                       = vault_kubernetes_secret_backend.kubernetes.path
  name                          = "admin"
  kubernetes_role_name          = "cluster-admin"
  kubernetes_role_type          = "ClusterRole"
  allowed_kubernetes_namespaces = ["*"]
}

# Lets GitHub Actions log in to Vault with its OIDC token. The roles are made by github-deployment-role for each
# self-deploying app, and below for this repository's own workflows.
resource "vault_jwt_auth_backend" "github" {
  path               = "github"
  type               = "oidc"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "1h"
    token_type        = "default-service"
  }
}

locals {
  # Each of coven's reusable workflows, and the environments it may run in. Only main's copy of the workflow, running
  # in one of those environments, can log in (ADR 006). Keep in step with coven_ci_workflows in
  # coven/bootstrap/githubactions.tf.
  coven_ci_workflows = {
    "tfplan"          = { workflow = "tfplan-stack.yml", environments = ["coven-plan", "coven-plan-review"] }
    "tfapply"         = { workflow = "tfapply-stack.yml", environments = ["coven"] }
    "configure-hosts" = { workflow = "configure-hosts.yml", environments = ["coven"] }
  }

  coven_ci_bound_claims = {
    for name, ci in local.coven_ci_workflows : name => {
      # gh api repos/omelette-gay/coven --jq .id. The ID, not the name, so a repository that takes the name later
      # doesn't inherit this trust.
      repository_id = "1469182305"
      # Set by GitHub to the reusable workflow's own path and ref. A pull request's or branch's copy of the workflow,
      # or its steps copied into another workflow, get a different value.
      job_workflow_ref = "omelette-gay/coven/.github/workflows/${ci.workflow}@refs/heads/main"
      # The provider splits a comma-separated value into a list, any of which matches. A job without an environment
      # has no environment claim, so it's refused.
      environment = join(",", ci.environments)
    }
  }
}

# coven's reusable workflows, as admins. Each has its own role, so Vault's audit log shows which one acted.
resource "vault_jwt_auth_backend_role" "coven_ci" {
  for_each = local.coven_ci_bound_claims

  backend           = vault_jwt_auth_backend.github.path
  role_name         = "coven-${each.key}"
  role_type         = "jwt"
  user_claim        = "actor"
  bound_audiences   = ["https://github.com/omelette-gay"]
  bound_claims_type = "string" # exact matches, not globs
  bound_claims      = each.value
  token_policies    = [vault_policy.admin.name]
}

# People log in to Vault through Keycloak, and those with the vault-admin role (the admins group) get the admin policy
ephemeral "random_password" "vault_client_secret" {
  length  = 64
  special = false
}

resource "keycloak_openid_client" "vault" {
  realm_id              = keycloak_realm.omelette_gay.id
  client_id             = "vault"
  name                  = "vault"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  root_url              = "https://${var.vault_host}"
  valid_redirect_uris = [
    "https://${var.vault_host}/ui/vault/auth/keycloak/oidc/callback",
    "http://localhost:8250/oidc/callback", # for CLI login
  ]

  # also written to Vault below, together, when vault_keycloak_secret_revision changes
  client_secret_wo         = ephemeral.random_password.vault_client_secret.result
  client_secret_wo_version = tostring(var.vault_keycloak_secret_revision)
}

resource "keycloak_openid_user_client_role_protocol_mapper" "vault_roles" {
  realm_id                    = keycloak_realm.omelette_gay.id
  client_id                   = keycloak_openid_client.vault.id
  name                        = "client roles"
  claim_name                  = "roles"
  multivalued                 = true
  client_id_for_role_mappings = keycloak_openid_client.vault.client_id
  add_to_access_token         = true
  add_to_userinfo             = true
}

resource "keycloak_role" "vault_admin" {
  realm_id  = keycloak_realm.omelette_gay.id
  client_id = keycloak_openid_client.vault.id
  name      = "vault-admin"
}

resource "keycloak_group_roles" "admins_vault" {
  realm_id   = keycloak_realm.omelette_gay.id
  group_id   = keycloak_group.admins.id
  role_ids   = [keycloak_role.vault_admin.id]
  exhaustive = false
}

# On the testlab, Keycloak's certificate comes from Vault's own CA, and Vault checks Keycloak's discovery URL against
# that CA when its config is written. On a fresh cluster Keycloak has no certificate from the CA until cert-manager
# issues one, once the Vault ClusterIssuer exists, so wait for it here or Vault rejects the config. (After the CA is
# replaced, existing certificates have to be re-issued by hand, as they're still valid.)
data "http" "keycloak_discovery" {
  count = var.insecure_tls ? 1 : 0

  url         = "${var.keycloak_url}/realms/${keycloak_realm.omelette_gay.realm}/.well-known/openid-configuration"
  ca_cert_pem = vault_pki_secret_backend_root_cert.cluster.certificate

  retry {
    attempts     = 60
    min_delay_ms = 10000
    max_delay_ms = 10000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Keycloak's discovery URL didn't return 200."
    }
  }

  depends_on = [kubernetes_manifest.vault_cluster_issuer]
}

resource "vault_jwt_auth_backend" "keycloak" {
  path                  = "keycloak"
  type                  = "oidc"
  oidc_discovery_url    = "${var.keycloak_url}/realms/${keycloak_realm.omelette_gay.realm}"
  oidc_discovery_ca_pem = var.insecure_tls ? vault_pki_secret_backend_root_cert.cluster.certificate : null
  oidc_client_id        = keycloak_openid_client.vault.client_id

  oidc_client_secret_wo         = ephemeral.random_password.vault_client_secret.result
  oidc_client_secret_wo_version = var.vault_keycloak_secret_revision

  tune {
    default_lease_ttl = "8h"
    max_lease_ttl     = "8h"
    token_type        = "default-service"
  }

  depends_on = [data.http.keycloak_discovery]
}

resource "vault_jwt_auth_backend_role" "keycloak_admin" {
  backend    = vault_jwt_auth_backend.keycloak.path
  role_name  = "admin"
  role_type  = "oidc"
  user_claim = "preferred_username"
  # only tokens issued for Vault can be used to log in
  bound_audiences = [keycloak_openid_client.vault.client_id]
  # only people with Vault's admin role in Keycloak
  bound_claims = {
    roles = keycloak_role.vault_admin.name
  }
  token_policies        = [vault_policy.admin.name]
  token_max_ttl         = 8 * 60 * 60
  allowed_redirect_uris = keycloak_openid_client.vault.valid_redirect_uris
}
