# Names and Numbers

This document explains the naming scheme and important numbers associated with our infrastructure.
(Personal devices are exempt from this and named according to the whims of their owners!).

## Domain names

Our primary domain name is omelette.gay.

Services which are exposed to the outside world are named "service.omelette.gay" (or on the root
using DNS-SD if there's a single instance needed and the service uses DNS-SD), e.g., tasks.omelette.gay.

Infrastructure related services (e.g., monitoring) and other pieces of infrastructure names (e.g.,
machines) are then named under a subdomain corresponding to the network it is on, or the cluster
it is in, e.g., "janus.gs.omelette.gay".

## Kubernetes Clusters

The k8s clusters are named according to collections of things, with the individual hosts within that
named according to instances of things.

### Coven

This is our primary (and currently only) k8s cluster.

- **Subdomain**: coven.omelette.gay.

#### Hosts

- _strix_: hosted in external datacentre [Hetzner FSN1-DC15](https://docs.hetzner.com/general/others/data-centers-and-connection/)
- _grimhilde_: Chris's old Mac Mini at home

## Networks

The network hardware is named either after gatekeepers for routers, or TV transmitters for wi-fi access points.

### Home network

- **Subdomain**: gs.omelette.gay
- **Public IPv4**: 51.148.152.196/32
- **Private IPv4**: 192.168.178.0/24
- **IPv6**: 2a02:8012:e08f::/48

Currently, there is no DNS configured, and janus is configured on the root as it predates the subdomain policy.

#### Named bits of hardware

- _janus_: Main router (Roman god who can look both ways)
- _emleymoor_: Wi-fi access point/switch in Chris's office (primary TV transmitter for Yorkshire)
- _winterhill_: Wi-fi access point in main bedroom (primary TV transmitter for Manchester)

### External data centres

Devices which are hosted on external networks, rather than networks which we manage are classed as in an
external datacentre, and named in the subdomain `xdc.omelette.gay`.
