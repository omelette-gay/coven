# Factorio

Deploys a Factorio server, with an optional game password synced from Vault and an optional SRV record so players can
join by domain name.

- `port` has no default: every game server on the cluster shares strix's load balancer IP, so each needs its own.
- Set `password_protected` and put the password in Vault at `secret/factorio/<server_id>`, under the
  `game_password` key.
- Set `longhorn_recurring_job_name` to back the saves up off-site; otherwise they're only snapshotted locally.
- Set `preferred_node_labels` to `{ "coven.omelette.gay/location" = "xdc" }` to keep the server on strix, where the
  public IP is.
- `memory` is a request, not a limit. Set it a little above what the server uses, which grows with the size of the
  factory.
