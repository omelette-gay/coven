# Exposing services to the web over HTTPS

**WARNING:** this will not work on the Vagrant testlab (please see https://github.com/omelette-gay/coven/issues/28)

k3s uses Traefik by default as a reverse proxy through to the different services hosted in our cluster. Traefik on k8s
works by looking at all of the Ingress objects registered in k8s and then creating routing rules to send traffic
to the right service based on this (each ingress usually registers a hostname and a set of paths to route).

To finetune the Traefik configuration for a specific ingress, Traefik will look at the annotations on the Ingress
object in k8s and alter its configuration accordingly. [The list of annotations that can be added to an Ingress is in the Traefik documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/).

One annotation we can add is `traefik.ingress.kubernetes.io/router.middlewares: kube-system-redirect-https@kubernetescrd`
which will redirect all http traffic to https.

Rather than creating and managing certificates ourselves, we can use [cert-manager](https://cert-manager.io/) to do this.
For each certificate we want, we can then instead an annotation to the ingress of `cert-manager.io/cluster-issuer: letsencrypt`
and then configure the `tls` option to specify the secret the cert will be stored in. Cert manager will then request a
certificate and store it in this secret - when Traefik goes and looks at the Ingress definition, it will then read the
certificate from the secret which is managed by cert-manager.

Finally, we will need to create DNS entries for our services. [external-dns](https://kubernetes-sigs.github.io/external-dns/)
can be used to do this to create entries in Hetzner's DNS manager based on the hostnames specified in the Ingress.
This process should be automatic.
