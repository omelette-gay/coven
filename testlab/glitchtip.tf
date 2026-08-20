module "glitchtip" {
  source = "../tfmodules/glitchtip"

  domain         = "errors.coven.local"
  cluster_issuer = "vault"
}
