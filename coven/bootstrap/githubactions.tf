# Trust GitHub Actions to act in GCP. See ADR 006: only coven's reusable workflows on main, in the environment each one
# is allowed, get these roles.
#
# This file and workloadidentity.tf are applied by a project owner from their own machine. CI can read the pools but
# not change them, so it can't loosen the conditions that decide who gets its own roles.

resource "google_iam_workload_identity_pool" "omelette_gay_github_actions" {
  workload_identity_pool_id = "omelette-gay-github-actions"
}

locals {
  # gh api repos/omelette-gay/coven --jq .id. Binding on the ID rather than the name means a repository that takes the
  # name later doesn't inherit this trust.
  coven_repository_id = "1469182305"

  # Each of coven's reusable workflows and the environments it may run in. The principals below only match a token
  # with all three of these claims, from main's copy of the workflow. Keep in step with coven_ci_workflows in
  # tfmodules/stack-platform/vault.tf.
  coven_ci_workflows = {
    "tfplan-stack"    = ["coven-plan", "coven-plan-review"]
    "tfapply-stack"   = ["coven"]
    "configure-hosts" = ["coven"]
  }

  # job_workflow_ref for main's copy of each workflow => its short name
  coven_ci_workflow_refs = {
    for workflow in keys(local.coven_ci_workflows) : "omelette-gay/coven/.github/workflows/${workflow}.yml@refs/heads/main" => workflow
  }
}

# coven's provider, the only one in the pool.
resource "google_iam_workload_identity_pool_provider" "coven_github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.omelette_gay_github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "coven-github-actions"
  display_name                       = "coven GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.job_workflow_ref" = "assertion.job_workflow_ref"
    "attribute.environment"      = "assertion.environment"
    # All three in one attribute, as a principalSet can only match one: <repository ID>/<workflow>/<environment>, e.g.
    # 1469182305/tfplan-stack/coven-plan. The map turns main's copy of each reusable workflow into its short name, as
    # GCP doesn't document which characters a principalSet value can hold, and job_workflow_ref has an @. Any other
    # job_workflow_ref isn't in the map, and a job without an environment has no environment claim, so either way this
    # fails to evaluate and no principal matches.
    "attribute.workflow_environment" = "assertion.repository_id + '/' + ${jsonencode(local.coven_ci_workflow_refs)}[assertion.job_workflow_ref] + '/' + assertion.environment"
  }

  # GitHub uses one issuer for everyone, so this is what stops other repositories using this provider at all
  attribute_condition = "assertion.repository_id == '${local.coven_repository_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  github_pool = google_iam_workload_identity_pool.omelette_gay_github_actions.name

  coven_ci_principals = merge([
    for workflow, environments in local.coven_ci_workflows : {
      for environment in environments : "${workflow} ${environment}" => "principalSet://iam.googleapis.com/${local.github_pool}/attribute.workflow_environment/${local.coven_repository_id}/${workflow}/${environment}"
    }
  ]...)

  # CI's identities that plan and apply Terraform. They work in any GCP project, not just this one.
  terraform_ci_principals = {
    "tfplan-stack coven-plan"        = local.coven_ci_principals["tfplan-stack coven-plan"]
    "tfplan-stack coven-plan-review" = local.coven_ci_principals["tfplan-stack coven-plan-review"]
    "tfapply-stack coven"            = local.coven_ci_principals["tfapply-stack coven"]
  }

  # Everything that needs the k3s token: Terraform, and Ansible when it joins nodes to the cluster
  k3s_token_principals = merge(local.terraform_ci_principals, {
    "configure-hosts coven" = local.coven_ci_principals["configure-hosts coven"]
  })
}

resource "google_project_iam_member" "ci_editor" {
  for_each = local.terraform_ci_principals

  project = var.project_id
  role    = "roles/editor"
  member  = each.value
}

resource "google_secret_manager_secret_iam_member" "ci_k3s_token_accessor" {
  for_each = local.k3s_token_principals

  secret_id = google_secret_manager_secret.k3s_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

# Ansible's gcp_secret_manager lookup lists the secret's versions to find the latest before reading it, and
# secretAccessor doesn't include listing. Terraform's principals get it from roles/editor.
resource "google_secret_manager_secret_iam_member" "ci_k3s_token_viewer" {
  secret_id = google_secret_manager_secret.k3s_token.secret_id
  role      = "roles/secretmanager.viewer"
  member    = local.coven_ci_principals["configure-hosts coven"]
}

# Lets CI's plans read both workload identity pools and show drift. roles/editor doesn't cover them. CI can't change
# them: they're applied by a project owner (see the top of this file).
resource "google_project_iam_member" "ci_workload_identity_pool_viewer" {
  for_each = local.terraform_ci_principals

  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolViewer"
  member  = each.value
}

# Lets CI's plans and applies read the billing account and manage the budget in billing.tf. Not billing admin, which
# could change who has access to the billing account..
resource "google_billing_account_iam_member" "ci_costs_manager" {
  for_each = local.terraform_ci_principals

  billing_account_id = data.google_billing_account.account.id
  role               = "roles/billing.costsManager"
  member             = each.value
}

# Let CI manage apps' own GCP projects, whose contents are in the apps stack. CI can't change IAM, so these grants (and
# the APIs it needs before it can do anything in a project) are applied by a project owner from their own machine
# the first time a project is added. Owners are added by hand and aren't managed here.

locals {
  # Project IDs
  app_gcp_projects = toset([
    "chriss-weight-tracker",
  ])

  app_gcp_project_ci_roles = toset([
    "roles/browser",                        # read the project and its IAM policy
    "roles/serviceusage.serviceUsageAdmin", # enable APIs
    "roles/iam.serviceAccountAdmin",        # manage service accounts and who can act as them
  ])

  app_gcp_project_bootstrap_services = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
  ])
}

resource "google_project_service" "app_gcp_project_bootstrap" {
  for_each = {
    for pair in setproduct(local.app_gcp_projects, local.app_gcp_project_bootstrap_services) : "${pair[0]} ${pair[1]}" => {
      project = pair[0]
      service = pair[1]
    }
  }

  project            = each.value.project
  service            = each.value.service
  disable_on_destroy = false
}

resource "google_project_iam_member" "app_gcp_project_ci_roles" {
  for_each = {
    for triple in setproduct(local.app_gcp_projects, local.app_gcp_project_ci_roles, keys(local.terraform_ci_principals)) : "${triple[0]} ${triple[1]} ${triple[2]}" => {
      project = triple[0]
      role    = triple[1]
      member  = local.terraform_ci_principals[triple[2]]
    }
  }

  project = each.value.project
  role    = each.value.role
  member  = each.value.member

  depends_on = [google_project_service.app_gcp_project_bootstrap]
}
