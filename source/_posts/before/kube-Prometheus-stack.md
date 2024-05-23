---
title: kube-prometheus-stack
author: LC
toc: true
date: 2024-04-30 23:15:54
img:
top: true
cover:
password:
summary: kube-prometheus-stack是prometheus监控k8s集群的套件，可以通过helm一键安装，同时带有监控的模板。
categories: kubernetes
tags: [prometheus]
---

在 kube-prometheus-stack 中，prometheus 资源对象（crd 对象，而不是 prometheus 这个应用）需要对以下内容特别注意
prometheus 对象的 yaml 部分内容   
```
  namespaceselector：
    any: true
  serviceMonitorSelector:
    matchLabels:
      release: kube-prometheus-stack   # note：当 servicemonitor 没有正常生效时，检查其资源中是否有这样的标签，如此才能被prometheus对象所选择 ，而后生效
```

书写一个 servicemonitor。
```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    objectset.rio.cattle.io/hash: f3ca87e2e941644e0d103f8e0d05b2e610db5092
    release: kube-prometheus-stack
  name: kube-prometheus-stack-rocketchat
  namespace: kube-prom
spec:
  endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: metrics
  jobLabel: jobLabel
  namespaceSelector:
    matchNames:
      - rocketchat
  selector:
    matchLabels:
      app.kubernetes.io/instance: rocketchat
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/name: rocketchat
```

书写服务自动发现。
通过命令和文件创建的 secret
```
vim sd.yaml
kubectl create secret generic kube-prometheus-stack-sd --from-file=./sd.yaml -n kube-prom
secret/kube-prometheus-stack-sd created
```

配置使用这个secret
```
prometheus:
  prometheusspec:
    additionalScrapeConfigsSecret: {}
      enabled: false
      name: kube-prometheus-stack-sd
      key: sd.yaml
```

sd.yaml
```
- job_name: kubernetes-service-endpoints
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    - action: keep
      regex: true
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape
    - action: drop
      regex: true
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_slow
    - action: replace
      regex: (https?)
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
      target_label: __scheme__
    - action: replace
      regex: (.+)
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
      target_label: __metrics_path__
    - action: replace
      regex: (.+?)(?::\d+)?;(\d+)
      replacement: $1:$2
      source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
      target_label: __address__
    - action: labelmap
      regex: __meta_kubernetes_service_label_app_(.+)
      replacement: __param_$1
    - action: replace
      regex: __meta_kubernetes_service_label_(.+)
      source_labels:
        - __meta_kubernetes_namespace
      target_label: namespace
    - action: replace
      source_labels:
        - __meta_kubernetes_service_name
      target_label: service
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_node_name
      target_label: node
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_name
      target_label: pod
- job_name: kubernetes-service-endpoints-slow
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    - action: keep
      regex: true
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_slow
    - action: replace
      regex: (https?)
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
      target_label: __scheme__
    - action: replace
      regex: (.+)
      source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
      target_label: __metrics_path__
    - action: replace
      regex: (.+?)(?::\d+)?;(\d+)
      replacement: $1:$2
      source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
      target_label: __address__
    - action: labelmap
      regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
      replacement: __param_$1
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - action: replace
      source_labels:
        - __meta_kubernetes_namespace
      target_label: namespace
    - action: replace
      source_labels:
        - __meta_kubernetes_service_name
      target_label: service
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_node_name
      target_label: node
  scrape_interval: 5m
  scrape_timeout: 30s
- honor_labels: true
  job_name: kubernetes-pods
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - action: keep
      regex: true
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape
    - action: drop
      regex: true
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape_slow
    - action: replace
      regex: (https?)
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scheme
      target_label: __scheme__
    - action: replace
      regex: (.+)
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
      target_label: __metrics_path__
    - action: replace
      regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
      replacement: '[$2]:$1'
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
      target_label: __address__
    - action: replace
      regex: (\d+);((([0-9]+?)(\.|$)){4})
      replacement: $2:$1
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
      target_label: __address__
    - action: labelmap
      regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
      replacement: __param_$1
    - action: replace
      source_labels:
        - __meta_kubernetes_namespace
      target_label: namespace
    - action：replace
      source_labels:
        - __meta_kubernetes_pod_label_release
      target_labels: release
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_name
      target_label: pod
    - action: drop
      regex: Pending|Succeeded|Failed|Completed
      source_labels:
        - __meta_kubernetes_pod_phase
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_node_name
      target_label: node
- honor_labels: true
  job_name: kubernetes-pods-slow
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - action: keep
      regex: true
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape_slow
    - action: replace
      regex: (https?)
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scheme
      target_label: __scheme__
    - action: replace
      regex: (.+)
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
      target_label: __metrics_path__
    - action: replace
      regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
      replacement: '[$2]:$1'
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
      target_label: __address__
    - action: replace
      regex: (\d+);((([0-9]+?)(\.|$)){4})
      replacement: $2:$1
      source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
      target_label: __address__
    - action: labelmap
      regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
      replacement: __param_$1
    - action：replace
      source_labels:
        - __meta_kubernetes_pod_label_release
      target_labels: release
    - action: replace
      source_labels:
        - __meta_kubernetes_namespace
      target_label: namespace
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_name
      target_label: pod
    - action: drop
      regex: Pending|Succeeded|Failed|Completed
      source_labels:
        - __meta_kubernetes_pod_phase
    - action: replace
      source_labels:
        - __meta_kubernetes_pod_node_name
      target_label: node
  scrape_interval: 5m
  scrape_timeout: 30s
```


在 Prometheus 中， `relabel_config` 用于在抓取目标之前对目标的标签进行重写，这在服务发现和数据组织中非常有用。以下是 `relabel_config` 中可以使用的所有参数的详细介绍：

1. **`action`**: 指定要执行的操作，可用的动作包括：
   - `replace`: 替换标签的键或值。
   - `keep`: 保留匹配正则表达式的实例，丢弃其他实例。
   - `drop`: 丢弃匹配正则表达式的实例，保留其他实例。
   - `labelmap`: 将一个标签映射到另一个标签，可以用于重命名或重组标签。
   - `labeldrop`: 删除指定的标签。
   - `labelkeep`: 仅保留指定的标签，删除其他所有标签。

2. **`source_labels`**: 一个包含要进行重写的原始标签名的数组。对于`replace`动作，至少需要一个标签；对于`keep`、`drop`、`labeldrop`和`labelkeep`动作，通常需要指定要匹配的标签。

3. **`regex`**: 一个正则表达式，用于匹配`source_labels`中的标签值。对于`replace`动作，它可以是一个固定的字符串或者正则表达式；对于`keep`和`drop`动作，它通常是一个用于匹配的正则表达式。

4. **`target_label`**: 对于`replace`动作，这是要设置的新标签名。对于其他动作，这个字段不被使用。

5. **`replacement`**: 对于`replace`动作，这是新标签的值。它可以使用正则表达式捕获组（如`$1`），以动态设置新值。

6. **`separator`**: 对于`labelmap`动作，这是一个字符串，用于分隔复合标签中的各个部分。

7. **`modulus`**: 对于`hashmod`动作，这是一个整数，表示将标签值映射到一个特定的基数。

8. **`hash_mapping_file`**: 对于`hashmod`动作，这是一个文件路径，指定了一个包含标签值到特定基数映射的文件。

9. **`labeldrop`**: 用于删除匹配正则表达式的标签。

10. **`labelkeep`**: 用于保留匹配正则表达式的标签，删除其他所有标签。

11. **`tmp_label_name`**: 一个临时标签名，用于在重写过程中存储中间结果。

这些参数可以组合使用，以实现复杂的重写逻辑。例如，您可以先使用`labeldrop`删除不需要的标签，然后使用`replace`修改或添加新的标签，最后使用`labelmap`重命名标签以符合您的数据模型。

`relabel_config`的使用非常灵活，可以根据您的具体需求进行调整。在实际应用中，您可能需要结合您的服务发现机制、数据模型以及Prometheus的配置来设计合适的`relabel_config`。