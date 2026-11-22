# Logging

Installs [Loki](https://grafana.com/oss/loki/) in single-binary mode, with its logs in a RustFS object store (the
[object-store](../object-store/) module), and [Alloy](https://grafana.com/oss/alloy/) on every node, which sends pods'
logs, the systemd journal and Kubernetes events to Loki. Adds Loki to Grafana as a data source. Called by the platform
stack.

Logs are kept for 12 weeks. Loki's volume isn't backed up, as losing logs is acceptable.
