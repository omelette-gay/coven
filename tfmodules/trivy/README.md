# Trivy

Installs the Trivy Operator onto the cluster.

It's configured with `ignoreUnfixed`, so vulnerability reports only include vulnerabilities that have a fixed version
available, i.e. ones an image update can clear.
