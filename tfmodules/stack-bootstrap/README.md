# Bootstrap stack

The content of the bootstrap stack, the first of the three Terraform stacks described in
[ADR 002](../../docs/adr/002-three-stack-terraform-for-cluster-configuration.md). It's called by the thin root modules
in [coven/bootstrap/](../../coven/bootstrap/) and [testlab/bootstrap/](../../testlab/bootstrap/), which set the
backend, providers and variables, and hold resources that only exist in one environment (on coven, the GCP project and
the `omelette.gay` DNS zone).

Bootstrap installs operators, CRDs and base services. It can't use the `vault` or `keycloak` providers, as those
services are installed here.

## Layout

Each service is a module: [longhorn](../longhorn/), [kube-prometheus-stack](../kube-prometheus-stack/),
[cert-manager](../cert-manager/), [cnpg](../cnpg/), [vault](../vault/), [external-secrets](../external-secrets/) and
[keycloak](../keycloak/). This stack holds what they share: the `monitoring` namespace and the Prometheus Operator CRDs
(installed first, as Longhorn needs them and kube-prometheus-stack needs Longhorn), and Traefik's config and HTTPS
redirect middleware.

The modules are ordered with `depends_on`. ADR 002 warns against `depends_on` on modules because it delays the module's
data sources until apply, so none of these modules has a data source: the controller nodes kube-prometheus-stack needs
are looked up here and passed in.

## Conventions

Every `helm_release` sets `atomic = true`, so a failed upgrade is rolled back instead of leaving the release stuck in a
`pending-*` state. Releases that take a while to start (kube-prometheus-stack, Keycloak) have a longer `timeout`. Names
that both stacks need (hostnames, the realm, the SMTP relay) are passed in by the root modules.
