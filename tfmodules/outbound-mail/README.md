# Outbound mail

Installs [docker-postfix](https://github.com/bokysan/docker-postfix), the SMTP relay apps in the cluster send mail
through (`smtp_host` and `smtp_port` in the outputs), signing it with DKIM. Called by the platform stack.

## DKIM

The DKIM key is generated as an ephemeral value, so it's never in Terraform state. The private key is written to Vault
(`mail/dkim`) and synced to the `dkim` Secret postfix mounts; the public key is written to a separate Vault secret
(`mail/dkim-public`) and read back for the DNS record. To rotate the key, increase `dkim_key_revision`, then restart
postfix (`kubectl rollout restart statefulset mail -n mail`). Mail may fail DKIM checks in between.

## DNS

If `dns_zone` is set, the DKIM, SPF and DMARC records for `domain` are published in it. SPF allows `ipv4_addresses`,
so `node_selector` keeps postfix on a node that sends from one of them.
