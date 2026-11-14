# trust the gitops repo to acquire a role in GCP

resource "google_iam_workload_identity_pool" "omelette_gay_github_actions" {
  workload_identity_pool_id = "omelette-gay-github-actions"
}

resource "google_iam_workload_identity_pool_provider" "omelette_gay_github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.omelette_gay_github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "omelette-gay-github-actions"

  attribute_mapping = {
    "google.subject"                  = "assertion.sub"                   # Subject
    "attribute.sub"                   = "attribute.sub"                   # Subject
    "attribute.repository"            = "assertion.repository"            # The repository from where the workflow is running
    "attribute.aud"                   = "attribute.aud"                   # Audience
    "attribute.iss"                   = "attribute.iss"                   # Issuer
    "attribute.actor"                 = "assertion.actor"                 # The personal account that initiated the workflow run.
    "attribute.actor_id"              = "assertion.actor_id"              # The ID of personal account that initiated the workflow run.
    "attribute.base_ref"              = "assertion.base_ref"              # The target branch of the pull request in a workflow run.
    "attribute.environment"           = "assertion.environment"           # The name of the environment used by the job.
    "attribute.event_name"            = "assertion.event_name"            # The name of the event that triggered the workflow run.
    "attribute.head_ref"              = "assertion.head_ref"              # The source branch of the pull request in a workflow run.
    "attribute.job_workflow_ref"      = "assertion.job_workflow_ref"      # For jobs using a reusable workflow, the ref path to the reusable workflow. For more information, see "Using OpenID Connect with reusable workflows."
    "attribute.job_workflow_sha"      = "assertion.job_workflow_sha"      # For jobs using a reusable workflow, the commit SHA for the reusable workflow file.
    "attribute.ref"                   = "assertion.ref"                   # (Reference) The git ref that triggered the workflow run.
    "attribute.ref_type"              = "assertion.ref_type"              # The type of ref, for example: "branch".
    "attribute.repository_visibility" = "assertion.repository_visibility" # The visibility of the repository where the workflow is running. Accepts the following values: internal, private, or public.
    "attribute.repository_id"         = "assertion.repository_id"         # The ID of the repository from where the workflow is running.
    "attribute.repository_owner"      = "assertion.repository_owner"      # The name of the organization in which the repository is stored.
    "attribute.repository_owner_id"   = "assertion.repository_owner_id"   # The ID of the organization in which the repository is stored.
    "attribute.run_id"                = "assertion.run_id"                # The ID of the workflow run that triggered the workflow.
    "attribute.run_number"            = "assertion.run_number"            # The number of times this workflow has been run.
    "attribute.run_attempt"           = "assertion.run_attempt"           # The number of times this workflow run has been retried.
    "attribute.runner_environment"    = "assertion.runner_environment"    # The type of runner used by the job. Accepts the following values: github-hosted or self-hosted.
    "attribute.workflow"              = "assertion.workflow"              # The name of the workflow.
    "attribute.workflow_ref"          = "assertion.workflow_ref"          # The ref path to the workflow. For example, octocat/hello-world/.github/workflows/my-workflow.yml@refs/heads/my_branch.
    "attribute.workflow_sha"          = "assertion.workflow_sha"          # The commit SHA for the workflow file.
  }

  attribute_condition = "assertion.repository_owner=='omelette-gay'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  gitops_repo = "omelette-gay/gitops"

  # The gitops repo's workflows. This identity works in any GCP project, not just this one.
  gitops_repo_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.omelette_gay_github_actions.name}/attribute.repository/${local.gitops_repo}"
}

resource "google_project_iam_member" "gitops_repo_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = local.gitops_repo_principal
}

resource "google_secret_manager_secret_iam_member" "gitops_repo_k3s_token_accessor" {
  secret_id = google_secret_manager_secret.k3s_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.gitops_repo_principal
}

# Let CI manage the cluster's workload identity pool (in the platform stack). roles/editor doesn't cover it.
resource "google_project_iam_member" "gitops_repo_workload_identity_pools" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = local.gitops_repo_principal
}

# Let CI manage apps' own GCP projects, whose contents are in the apps stack. CI can't change IAM, so these grants (and
# the APIs it needs before it can do anything in a project) are applied by a project owner from their own machine
# the first time a project is added. Owners are added by hand and aren't managed here.

locals {
  # Project IDs
  app_gcp_projects = toset([
    "chriss-weight-tracker",
  ])

  app_gcp_project_gitops_roles = toset([
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

resource "google_project_iam_member" "app_gcp_project_gitops_roles" {
  for_each = {
    for pair in setproduct(local.app_gcp_projects, local.app_gcp_project_gitops_roles) : "${pair[0]} ${pair[1]}" => {
      project = pair[0]
      role    = pair[1]
    }
  }

  project = each.value.project
  role    = each.value.role
  member  = local.gitops_repo_principal

  depends_on = [google_project_service.app_gcp_project_bootstrap]
}
