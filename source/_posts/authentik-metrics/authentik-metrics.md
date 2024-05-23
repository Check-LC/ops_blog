---
title: authentik-metrics
author: LC
toc: true
date: 2024-05-23 17:40:35
img:
top:
cover:
password:
summary: authentik 在云原生的指标暴露尝试
categories: Kubernetes
tags: ['authentik', 'kubernetes', 'metrics']
---

## values

```
global.addPrometheusAnnotations: true
server.metrics.enabled: true
```
将启用一个 metrics-pod 来暴露 server 的指标，并为其添加 annotation;，这与 servicemonitor 二选其一;不会产生其他端点的错误访问。

## serviceMonitor
	以下好像是应用自动创建的,需要在新增其他组件的时候尝试验证

- outpost-proxy metrics
```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app.kubernetes.io/instance: proxy
    app.kubernetes.io/managed-by: goauthentik.io
    app.kubernetes.io/name: authentik-proxy
    app.kubernetes.io/version: 2024.4.0
    goauthentik.io/outpost-name: proxy
    goauthentik.io/outpost-type: proxy
    goauthentik.io/outpost-uuid: f868f7f70fa94a55a0b62c7904b334a4
  name: ak-outpost-proxy
  namespace: authentik
spec:
  endpoints:
    - path: /metrics
      port: http-metrics
  selector:
    matchLabels:
      app.kubernetes.io/instance: proxy
      app.kubernetes.io/managed-by: goauthentik.io
      app.kubernetes.io/name: authentik-proxy
      app.kubernetes.io/version: 2024.4.0
      goauthentik.io/outpost-name: proxy
      goauthentik.io/outpost-type: proxy
      goauthentik.io/outpost-uuid: f868f7f70fa94a55a0b62c7904b334a4
```

- oupost-ldap metrics
```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app.kubernetes.io/instance: ldap
    app.kubernetes.io/managed-by: goauthentik.io
    app.kubernetes.io/name: authentik-ldap
    app.kubernetes.io/version: 2024.4.0
    goauthentik.io/outpost-name: ldap
    goauthentik.io/outpost-type: ldap
    goauthentik.io/outpost-uuid: 976f5f77477a40f39e492cefe4a701a2
  name: ak-outpost-ldap
  namespace: authentik
spec:
  endpoints:
    - path: /metrics
      port: http-metrics
  selector:
    matchLabels:
      app.kubernetes.io/instance: ldap
      app.kubernetes.io/managed-by: goauthentik.io
      app.kubernetes.io/name: authentik-ldap
      app.kubernetes.io/version: 2024.4.0
      goauthentik.io/outpost-name: ldap
      goauthentik.io/outpost-type: ldap
      goauthentik.io/outpost-uuid: 976f5f77477a40f39e492cefe4a701a2
```