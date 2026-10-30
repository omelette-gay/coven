# Everything in this root module has moved into the bootstrap, platform and apps stacks (ADR 002), which import it.
# These blocks stop this root module managing it, without destroying anything. Once this has been applied, this root
# module (and its state, in the terraform/state prefix of coven-tfstate) can be deleted.

removed {
  from = google_project_service.iam

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.cloudresourcemanager

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.iamcredentials

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.sts

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.billing

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.billingbudgets

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_service.secretmanager

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_storage_bucket.tfstate_bucket

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_monitoring_notification_channel.budget_notification_channel_1

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_monitoring_notification_channel.budget_notification_channel_2

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_billing_budget.warningbudget

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_secret_manager_secret.k3s_token

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_iam_workload_identity_pool.omelette_gay_github_actions

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_iam_workload_identity_pool_provider.omelette_gay_github_actions

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_iam_member.gitops_repo_role

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_secret_manager_secret_iam_member.gitops_repo_k3s_token_accessor

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_storage_bucket.backup_bucket

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_service_account.backup_service_account

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_storage_bucket_iam_member.backup_writer

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.omelette_gay

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_kubernetes_secret_backend_role.gitops_github_action

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_policy.github_deployment

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_jwt_auth_backend_role.github_deployment

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_kv_secret_v2.backup_service_account_creds

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_kv_secret_v2.backup_service_account_key

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.glitchtip

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.animebots_co_uk

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.barcampmanchester_co_uk

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.chrisn_xyz

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.cjn_me_uk

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.dxhosting_co_uk

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.manchestertechnights_org

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.moretobooks_com

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone.pling_org_uk

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.fastmail

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone_rrset.chris_bsky

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone_rrset.dizzy_bsky

  lifecycle {
    destroy = false
  }
}

removed {
  from = hcloud_zone_rrset.emily_bsky

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.girlsclub_minecraft

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.trivy

  lifecycle {
    destroy = false
  }
}

# The backup service account keys can't be imported, so the platform stack creates new ones (rotating them early).
# Destroy the old keys, and their rotation timestamps, which only exist in Terraform state.

removed {
  from = time_rotating.backup_service_account_key_rotation

  lifecycle {
    destroy = true
  }
}

removed {
  from = time_static.backup_service_account_key_rotation

  lifecycle {
    destroy = true
  }
}

removed {
  from = google_storage_hmac_key.backup_service_account_key

  lifecycle {
    destroy = true
  }
}

removed {
  from = google_service_account_key.backup_service_account_key

  lifecycle {
    destroy = true
  }
}
