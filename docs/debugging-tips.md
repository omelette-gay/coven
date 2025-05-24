# Debugging Traefik

One of the best ways to look at Traefik issues is to interrogate the state via the Traefik dashboard. This is
enabled in "insecure" mode on our cluster, but this is okay as it's not directly exposed anywhere. To see it,
we'll need to be logged into the cluster and then create a port forward to our local machine to look at it.

    kubectl -n kube-system port-forward deployments/traefik 8080:8080

We can now visit http://localhost:8080/dashboard/ to view the dashboard.
