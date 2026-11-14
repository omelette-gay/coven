# GitHub deployment role

Lets a GitHub repo deploy to a namespace, for a self-deploying app (see [deploying apps](../../docs/deploying-apps.md)).
The repo's GitHub Actions log in to Vault with their OIDC token, using
[vault-k8s-login-action](https://github.com/omelette-gay/vault-k8s-login-action/) with `vault-k8s-role: github-<role_name>`,
and get short-lived cluster-admin credentials that only work in that namespace.

The namespace comes from [app-namespace](../app-namespace/), and secrets and SSO from
[vault-k8s-secret](../vault-k8s-secret/) and [keycloak-client](../keycloak-client/). Several repos can share a namespace,
so call this module once per repo.
