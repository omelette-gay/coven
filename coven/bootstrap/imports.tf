# Imports what Ansible installed into the bootstrap stack (#561). Remove these blocks once they've been applied.

import {
  to = module.bootstrap.kubernetes_namespace_v1.monitoring
  id = "monitoring"
}

import {
  to = module.bootstrap.kubernetes_namespace_v1.longhorn
  id = "longhorn-system"
}

import {
  to = module.bootstrap.kubernetes_namespace_v1.cert_manager
  id = "cert-manager"
}

import {
  to = module.bootstrap.helm_release.longhorn
  id = "longhorn-system/longhorn"
}

import {
  to = module.bootstrap.helm_release.kube_prometheus_stack
  id = "monitoring/kube-prometheus"
}

import {
  to = module.bootstrap.helm_release.blackbox_exporter
  id = "monitoring/blackbox-exporter"
}

import {
  to = module.bootstrap.helm_release.helm_exporter
  id = "monitoring/helm-exporter"
}

import {
  to = module.bootstrap.kubernetes_manifest.traefik_config
  id = "apiVersion=helm.cattle.io/v1,kind=HelmChartConfig,namespace=kube-system,name=traefik"
}

import {
  to = module.bootstrap.helm_release.cert_manager
  id = "cert-manager/cert-manager"
}

import {
  to = module.bootstrap.kubernetes_manifest.redirect_https
  id = "apiVersion=traefik.io/v1alpha1,kind=Middleware,namespace=kube-system,name=redirect-https"
}
