# GCP workload identity

Lets pods running as a Kubernetes service account act as a GCP service account, without a key, through the cluster's
workload identity pool (in the platform stack).

Creates the Kubernetes service account, lets it act as the GCP service account, and creates a ConfigMap holding a
credentials file for Google's client libraries, with nothing secret in it. The app's pods need to:

- run as `k8s_service_account_name`
- mount a projected service account token with the ConfigMap's `audience`, at the ConfigMap's `token_path`
- mount the ConfigMap's `credentials.json` and point `GOOGLE_APPLICATION_CREDENTIALS` at it

This only works for software that uses Google's client libraries (or otherwise supports `external_account`
credentials). Software that signs its own tokens with a service account's private key needs a key.
