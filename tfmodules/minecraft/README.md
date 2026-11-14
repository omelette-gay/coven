# Minecraft

Deploys a Minecraft server, with optional world backups and an optional SRV record so players can join by domain name.

- `port` has no default: every game server on the cluster shares strix's load balancer IP, so each needs its own.
- `memory` is the JVM heap in whole gigabytes (e.g. `4G`); the pod requests 1G more for the JVM's own overhead.
- Set `backups_enabled` to back the world up to a separate volume, and `longhorn_recurring_job_name` to back that
  volume up off-site.
  The backup sidecar's RCON password is generated and kept in Vault (`minecraft/<server_id>/rcon`), and synced into the
  `<server_id>-rcon-password` Secret by External Secrets Operator, so it isn't in Terraform state.
- Set `preferred_node_labels` to `{ "coven.omelette.gay/location" = "xdc" }` to keep the server on strix, where the
  public IP is.
