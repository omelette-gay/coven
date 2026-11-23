# Trust GitHub Actions to acquire a role in the kubernetes cluster.

# coven's reusable workflows that run Terraform, as cluster-admin, each with its own role so the service accounts Vault
# creates show which one acted. They're bound on the same claims as their admin roles in Vault (ADR 006).
locals {
  coven_ci_kubernetes = {
    for name in ["tfplan", "tfapply"] : name => module.platform.coven_ci_bound_claims[name]
  }
}

resource "vault_kubernetes_secret_backend_role" "coven_ci" {
  for_each = local.coven_ci_kubernetes

  backend                       = module.platform.vault_kubernetes_secret_backend
  name                          = "github-coven-${each.key}"
  allowed_kubernetes_namespaces = ["*"]
  kubernetes_role_name          = "cluster-admin"
  kubernetes_role_type          = "ClusterRole"
}

resource "vault_policy" "coven_ci_kubernetes" {
  for_each = local.coven_ci_kubernetes

  name = "github-coven-${each.key}"

  policy = <<EOT
path "${module.platform.vault_kubernetes_secret_backend}/creds/${vault_kubernetes_secret_backend_role.coven_ci[each.key].name}" {
  capabilities = ["update"]
}
EOT
}

resource "vault_jwt_auth_backend_role" "coven_ci_kubernetes" {
  for_each = local.coven_ci_kubernetes

  backend           = module.platform.vault_github_auth_backend
  role_name         = "github-coven-${each.key}"
  role_type         = "jwt"
  user_claim        = "actor"
  token_policies    = [vault_policy.coven_ci_kubernetes[each.key].name]
  bound_audiences   = ["https://github.com/omelette-gay"]
  bound_claims_type = "string" # exact matches, not globs
  bound_claims      = each.value
}
