# Bootstrap stack

The content of the bootstrap stack, the first of the three Terraform stacks described in
[ADR 002](../../docs/adr/002-three-stack-terraform-for-cluster-configuration.md). It's called by the thin root modules
in [coven/bootstrap/](../../coven/bootstrap/) and [testlab/bootstrap/](../../testlab/bootstrap/), which set the
backend, providers and variables, and hold resources that only exist in one environment (on coven, the GCP project and
the `omelette.gay` DNS zone).

Bootstrap installs operators, CRDs and base services. It can't use the `vault` or `keycloak` providers, as those
services are installed here.
