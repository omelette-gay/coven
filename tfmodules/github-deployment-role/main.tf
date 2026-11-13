terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
  }
}

locals {
  vault_name = "github-${var.role_name}"
}

# The Vault role that issues Kubernetes credentials: cluster-admin, but only in the app's namespace
resource "vault_kubernetes_secret_backend_role" "this" {
  backend                       = "kubernetes"
  name                          = local.vault_name
  allowed_kubernetes_namespaces = [var.k8s_namespace]
  kubernetes_role_name          = "cluster-admin"
  kubernetes_role_type          = "ClusterRole"
}

resource "vault_policy" "this" {
  name = local.vault_name

  policy = chomp(<<-EOT
    path "kubernetes/creds/${vault_kubernetes_secret_backend_role.this.name}" {
      capabilities = ["update"]
    }
  EOT
  )
}

# Lets GitHub Actions in the repo log in to Vault with its OIDC token, and get the policy above
resource "vault_jwt_auth_backend_role" "this" {
  backend         = "github"
  role_name       = local.vault_name
  role_type       = "jwt"
  user_claim      = "actor"
  token_policies  = [vault_policy.this.name]
  bound_audiences = ["https://github.com/${split("/", var.github_repo)[0]}"]

  bound_claims = {
    repository = var.github_repo
  }
}
