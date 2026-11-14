# App namespace

Creates the namespace for a self-deploying app (see [deploying apps](../../docs/deploying-apps.md)) and, if
`ghcr_secret_name` is set, syncs the shared GitHub Container Registry credentials from Vault into it so the app can pull
private images.

Several repos can deploy into one namespace, so the namespace is separate from [github-deployment-role](../github-deployment-role/),
which is per repo.
