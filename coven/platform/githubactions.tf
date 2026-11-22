# trust the gitops repo to acquire a role in the kubernetes cluster

resource "vault_kubernetes_secret_backend_role" "gitops_github_action" {
  backend                       = module.platform.vault_kubernetes_secret_backend
  name                          = "github-gitops"
  allowed_kubernetes_namespaces = ["*"]
  kubernetes_role_name          = "cluster-admin"
  kubernetes_role_type          = "ClusterRole"
}

resource "vault_policy" "github_deployment" {
  name = "github-gitops"

  policy = <<EOT
path "${module.platform.vault_kubernetes_secret_backend}/creds/${vault_kubernetes_secret_backend_role.gitops_github_action.name}" {
  capabilities = ["update"]
}
EOT
}

resource "vault_jwt_auth_backend_role" "github_deployment" {
  backend         = module.platform.vault_github_auth_backend
  role_name       = "github-gitops"
  role_type       = "jwt"
  user_claim      = "actor"
  token_policies  = [vault_policy.github_deployment.name]
  bound_audiences = ["https://github.com/omelette-gay"]

  bound_claims = {
    repository = "omelette-gay/gitops"
  }
}
