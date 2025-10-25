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

resource "google_project_iam_member" "gitops_repo_role" {
  project = var.project_id
  role    = "roles/editor"
  member  = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.omelette_gay_github_actions.name}/attribute.repository/omelette-gay/gitops"
}
