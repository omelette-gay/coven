# Longhorn

Installs [Longhorn](https://longhorn.io/), our default storage class, and stops k3s's local-path class being the
default. Called by the bootstrap stack.

The iSCSI packages Longhorn needs on each node are installed by the `omelette.storage` Ansible role. Backups go to
`s3://coven-backups`, with credentials and recurring backup and snapshot jobs that the platform stack makes, as they need
Vault and Longhorn's CRDs (see [backups and recovery](../../docs/backups-and-recovery.md)).

k3s puts the default-class annotation back on local-path when it restarts. The next plan shows it, and the next apply
removes it again.
