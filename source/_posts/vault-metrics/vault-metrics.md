---
title: vault-metrics
author: LC
toc: true
date: 2024-05-23 17:52:50
img:
top:
cover:
password:
summary: nextcloud 在云原生的指标暴露尝试
categories: Kubernetes
tags: ['nextcloud','kubernetes','metrics']
---

## 以下是在 kubernetes 集群的自动发现
### vault helm chart
#### 保证 server.standalone  config 配置如下
```
config: |
      ui = true

      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        # Enable unauthenticated metrics access (necessary for Prometheus Operator)
        telemetry {
          unauthenticated_metrics_access = "true"
        }
      }
      storage "file" {
        path = "/vault/data"
      }
      # Example configuration for enabling Prometheus metrics in your config. 必须配置
      telemetry {
        prometheus_retention_time = "3d"
        disable_hostname = true
      }
```
### 开启 servicemonitor 

`serverTelemetry.serviceMonitor.enabled：true`

### Debug
服务成功发现，但是 prometheus targets 中报错 `server returned HTTP status 400 Bad Request` ，以下是集群内 curl 容器 api 的结果
```
curl  10.42.169.106:8200/v1/sys/metrics/
{"errors":["permission denied"]}

curl  10.42.169.106:8200/v1/sys/metrics 
{"Timestamp":"2024-04-15 03:07:50 +0000 UTC","Gauges":[{"Name":"vault.core.active","Value":1,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.in_flight_requests","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.mount_table.num_entries","Value":1,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"false","type":"auth"}},{"Name":"vault.core.mount_table.num_entries","Value":2,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"false","type":"logical"}},{"Name":"vault.core.mount_table.num_entries","Value":1,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"true","type":"logical"}},{"Name":"vault.core.mount_table.size","Value":253,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"false","type":"auth"}},{"Name":"vault.core.mount_table.size","Value":447,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"false","type":"logical"}},{"Name":"vault.core.mount_table.size","Value":302,"Labels":{"cluster":"vault-cluster-d79f20a5","local":"true","type":"logical"}},{"Name":"vault.core.performance_standby","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.replication.dr.primary","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.replication.dr.secondary","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.replication.performance.primary","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.replication.performance.secondary","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.replication.write_undo_logs","Value":0,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.core.unsealed","Value":1,"Labels":{"cluster":"vault-cluster-d79f20a5"}},{"Name":"vault.expire.num_irrevocable_leases","Value":0,"Labels":{}},{"Name":"vault.expire.num_leases","Value":0,"Labels":{}},{"Name":"vault.runtime.alloc_bytes","Value":47050330,"Labels":{}},{"Name":"vault.runtime.free_count","Value":115420530,"Labels":{}},{"Name":"vault.runtime.heap_objects","Value":92536,"Labels":{}},{"Name":"vault.runtime.malloc_count","Value":115513064,"Labels":{}},{"Name":"vault.runtime.num_goroutines","Value":224,"Labels":{}},{"Name":"vault.runtime.sys_bytes","Value":81191190,"Labels":{}},{"Name":"vault.runtime.total_gc_pause_ns","Value":345062720,"Labels":{}},{"Name":"vault.runtime.total_gc_runs","Value":2005,"Labels":{}}],"Points":[],"Counters":[{"Name":"vault.audit.log_request_failure","Count":1,"Rate":0,"Sum":0,"Min":0,"Max":0,"Mean":0,"Stddev":0,"Labels":{}},{"Name":"vault.audit.log_response_failure","Count":1,"Rate":0,"Sum":0,"Min":0,"Max":0,"Mean":0,"Stddev":0,"Labels":{}},{"Name":"vault.cache.hit","Count":2,"Rate":0.2,"Sum":2,"Min":1,"Max":1,"Mean":1,"Stddev":0,"Labels":{}}],"Samples":[{"Name":"vault.audit.log_request","Count":1,"Rate":0.00067349998280406,"Sum":0.0067349998280406,"Min":0.0067349998280406,"Max":0.0067349998280406,"Mean":0.0067349998280406,"Stddev":0,"Labels":{}},{"Name":"vault.audit.log_response","Count":1,"Rate":0.00048179998993873595,"Sum":0.00481799989938736,"Min":0.00481799989938736,"Max":0.00481799989938736,"Mean":0.00481799989938736,"Stddev":0,"Labels":{}},{"Name":"vault.barrier.get","Count":2,"Rate":0.007432200014591217,"Sum":0.07432200014591217,"Min":0.027681000530719757,"Max":0.04664099961519241,"Mean":0.037161000072956085,"Stddev":0.013406743923921348,"Labels":{}},{"Name":"vault.core.check_token","Count":1,"Rate":0.01593659967184067,"Sum":0.15936599671840668,"Min":0.15936599671840668,"Max":0.15936599671840668,"Mean":0.15936599671840668,"Stddev":0,"Labels":{}},{"Name":"vault.core.fetch_acl_and_token","Count":1,"Rate":0.014495299756526947,"Sum":0.14495299756526947,"Min":0.14495299756526947,"Max":0.14495299756526947,"Mean":0.14495299756526947,"Stddev":0,"Labels":{}},{"Name":"vault.core.handle_request","Count":1,"Rate":0.019178299605846404,"Sum":0.19178299605846405,"Min":0.19178299605846405,"Max":0.19178299605846405,"Mean":0.19178299605846405,"Stddev":0,"Labels":{}}]}

curl  10.42.169.106:8200/v1/sys/metrics?format="prometheus"
prometheus is not enabled> 
```

多次排查之后发现并无特别的问题，helm 部署之后多次修改调整 values 后，config 没有成功生效，其中的值没有成功传入容器。删除应用后重新安装转为正常。

## 以下是将 metrics 暴露到集群外
### 2. telemetry 授权
#### 2.1 在单节点配置文件部分添加这个块
```
telemetry {
        prometheus_retention_time = "30s"
        disable_hostname = true
}
```
#### 2.2 为 prometheus 创建访问的 token
- 权限
```
vault policy write prometheus-metrics - << EOF
path "/sys/metrics" {
  capabilities = ["read"]
}
EOF
```
- 创建具有权限的 token
```
vault token create \
  -field=token \
  -policy prometheus-metrics \
  > prometheus-token
```

将上方生成的 token 给予 prom。
### 3. prometheus 的配置
```bash
cat > prometheus.yml << EOF
scrape_configs:
  - job_name: vault
    metrics_path: /v1/sys/metrics
    params:
      format: ['prometheus']
    scheme: http
    authorization:
      credentials_file: /etc/prometheus/prometheus-token #使用 token
    static_configs:
    - targets: ['10.8.0.151:8200']
EOF
```
prom 热加载 `curl -X POST http://xxxx/-/reload`


## 第一次测试时 helm 主要修改内容
参考 helm 中 config 部分
values.yaml %% REGION %% 
```yaml TI:"values"

global.datastorage:

server:
  standalone:
    config: >
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        # Enable unauthenticated metrics access (necessary for Prometheus Operator)
        telemetry {
          unauthenticated_metrics_access = "true"
          unauthenticated_in_flight_request_access = "true" #此项应该无关prom metrics
        }
      }

      storage "file" {
        path = "/vault/data"
      }    

      # Example configuration for enabling Prometheus metrics in your config; when post outside your cluster
      telemetry {
        prometheus_retention_time = "3d"
        disable_hostname = true
      }
    enabled: 'true'
  statefulSet:
    annotations: {}
    securityContext:
      container: {}
      pod: {}
  terminationGracePeriodSeconds: 10
  tolerations: []
  topologySpreadConstraints: []
  updateStrategyType: OnDelete
  volumeMounts: null
  volumes: null
serverTelemetry:
  prometheusRules:
    enabled: true
    rules: []
    selectors: {}
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
    selectors: {}
```
%% ENDREGION %%
- 当前只是 standalone 配置
- server unseal 之后才能正常访问 UI

>[!failure]
> vault logs： `core: security barrier not initialized`
> 

>[!info]
> ```
> / $ vault operator init #进入容器执行
Unseal Key 1: D9apO9R7M9hL0PQaSByJ9pAEGy3EMIJZIrQDx+bHwhpy
Unseal Key 2: 0ixkSa4BM7X8Tre4F1JQDCR06m/AEtRUPD6DwvfecwD+
Unseal Key 3: 3y/sowvniDzofLE3AQnzvXujQSE894ocaQO61YTbU+r2
Unseal Key 4: dhkVbYBR7xqdl/Q+/QvvU9PofKdXu+OiYseqRuH8N7eo
Unseal Key 5: 5lP9+P6S/pBW0H6kPTSqktDOxn1LU1JO4HPR9TWeSJRo
>
Initial Root Token: hvs.UKtqCCot92t6cSlxsM7SW5br
>
Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.
>
Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!
>
It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
> 
>/ $ vault operator unseal 5lP9+P6S/pBW0H6kPTSqktDOxn1LU1JO4HPR9TWeSJRo  # 利用上述 key，重复执行 3 次即可解封 vault，这个 pod 将正常
> ```
