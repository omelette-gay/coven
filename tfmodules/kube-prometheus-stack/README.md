# kube-prometheus-stack

Installs [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
(Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics), plus the blackbox exporter and helm-exporter.
Called by the bootstrap stack.

## Values

The chart's values are split by section in [values/](./values/): Grafana, Prometheus, node-exporter, Alertmanager and
kube-state-metrics each have a file, and the k3s components (API server, kubelet, controller manager, scheduler, proxy
and DNS) are in `main.tf`, as they share a list of metrics to drop. Helm merges them in order, and no two set the same
key.

## Alerts

Our own alert rules are in [values/alerts/](./values/alerts/), one file per rule group. Each file is a
`PrometheusRule` spec (`groups: [...]`), and its name (without `.yaml`) becomes the group's key in
`additionalPrometheusRulesMap`. To add alerts, add a file. Alerts that come with a chart, such as Loki's, stay in that
chart.

## CRDs

The chart doesn't install the Prometheus Operator's CRDs (`crds.enabled: false`). The bootstrap stack installs them from
the `prometheus-operator-crds` chart first, as Longhorn needs them before this chart can have its volumes. They must never
be older than this chart's operator: Renovate puts major updates to the two in one pull request (see ADR 002).

## Grafana

Grafana logs people in through Keycloak only. Its client and the `grafana-keycloak-creds` Secret are made by the platform
stack; until then the Secret is missing and SSO doesn't work, but Grafana still starts. Grafana reads the Secret when it starts; the platform stack
restarts it when the client secret rotates.
