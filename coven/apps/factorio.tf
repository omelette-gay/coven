module "girlsclub_factorio" {
  source = "../../tfmodules/factorio"

  server_id = "girlsclub"
  dns = {
    hostname = "omelette.gay"
    zone     = data.hcloud_zone.omelette_gay
  }

  save_name          = "girls-club"
  server_name        = "Girls go Space"
  description        = "Just doing girls things, in space"
  password_protected = true
}

module "chegsworld_factorio" {
  source = "../../tfmodules/factorio"

  server_id = "chegsworld"
  port      = 31495
  dns = {
    hostname = "chegsworld.omelette.gay"
    zone     = data.hcloud_zone.omelette_gay
  }

  save_name          = "chegsworld"
  server_name        = "Chegs World"
  description        = "Making a factory a home"
  password_protected = true
}

# Imports the servers previously deployed by the omelette.factorio Ansible role. Remove once applied.

import {
  to = module.girlsclub_factorio.kubernetes_namespace_v1.this
  id = "factorio-girlsclub"
}

import {
  to = module.girlsclub_factorio.helm_release.factorio
  id = "factorio-girlsclub/girlsclub"
}

import {
  to = module.girlsclub_factorio.module.game_password[0].kubernetes_service_account_v1.reader
  id = "factorio-girlsclub/secret-reader"
}

import {
  to = module.girlsclub_factorio.module.game_password[0].vault_policy.reader
  id = "factorio-girlsclub"
}

import {
  to = module.girlsclub_factorio.module.game_password[0].vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/factorio-girlsclub"
}

import {
  to = module.girlsclub_factorio.module.game_password[0].kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=factorio-girlsclub,name=vault-factorio-girlsclub"
}

import {
  to = module.girlsclub_factorio.module.game_password[0].kubernetes_manifest.external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=factorio-girlsclub,name=game-password"
}

import {
  to = module.girlsclub_factorio.hcloud_zone_rrset.srv[0]
  id = "798597/_factorio._udp/SRV"
}

import {
  to = module.chegsworld_factorio.kubernetes_namespace_v1.this
  id = "factorio-chegsworld"
}

import {
  to = module.chegsworld_factorio.helm_release.factorio
  id = "factorio-chegsworld/chegsworld"
}

import {
  to = module.chegsworld_factorio.module.game_password[0].kubernetes_service_account_v1.reader
  id = "factorio-chegsworld/secret-reader"
}

import {
  to = module.chegsworld_factorio.module.game_password[0].vault_policy.reader
  id = "factorio-chegsworld"
}

import {
  to = module.chegsworld_factorio.module.game_password[0].vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/factorio-chegsworld"
}

import {
  to = module.chegsworld_factorio.module.game_password[0].kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=factorio-chegsworld,name=vault-factorio-chegsworld"
}

import {
  to = module.chegsworld_factorio.module.game_password[0].kubernetes_manifest.external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=factorio-chegsworld,name=game-password"
}

import {
  to = module.chegsworld_factorio.hcloud_zone_rrset.srv[0]
  id = "798597/_factorio._udp.chegsworld/SRV"
}
