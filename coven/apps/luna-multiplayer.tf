module "luna_multiplayer_girlsclub" {
  source = "../../tfmodules/luna-multiplayer"

  instance_name     = "girlsclub"
  chart_version     = "1.0.0"
  vault_secret_name = "luna-multiplayer/girlsclub"

  # Not templatefile(): it contains an External Secrets template, {{ .server_password }}
  values = [file("${path.module}/luna-multiplayer-girlsclub.yaml")]
}

# Adopt the resources that Ansible and the chart's old CI created. Remove these blocks once applied.
import {
  to = module.luna_multiplayer_girlsclub.kubernetes_namespace_v1.this
  id = "luna-multiplayer"
}

import {
  to = module.luna_multiplayer_girlsclub.helm_release.this
  id = "luna-multiplayer/girlsclub"
}

import {
  to = module.luna_multiplayer_girlsclub.module.secret_store.kubernetes_service_account_v1.reader
  id = "luna-multiplayer/luna-multiplayer-girlsclub-config"
}

import {
  to = module.luna_multiplayer_girlsclub.module.secret_store.vault_policy.reader
  id = "luna-multiplayer-girlsclub-config"
}

import {
  to = module.luna_multiplayer_girlsclub.module.secret_store.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/luna-multiplayer-girlsclub-config"
}

import {
  to = module.luna_multiplayer_girlsclub.module.secret_store.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=luna-multiplayer,name=vault-luna-multiplayer-girlsclub-config"
}
