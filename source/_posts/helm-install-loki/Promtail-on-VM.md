---
title: Promtail Running on VM
author: LC
toc: true
date: 2024-07-02 21:27:41
img:
top: false
cover:
password:
summary: 记录在 helm 和虚拟机安装 promtail 的踩坑，与收集必要的系统日志和特定服务的日志的过程
categories: OpenTelemetry
tags: ['loki', 'Log']
---

## Helm Deploy Promtail
### 两条重要日志

grafana congfig: Data source connected, but no labels received. Verify that Loki and Promtail is configured properly. 

promtail log：level=error ts=2024-06-19t06:14:50.369753384z caller=client.go:430 component=client host=loki-gateway msg="final error sending batch" status=401 tenant= error="server returned http status 401 unauthorized (401): no org id"

### **针对以上两条内容，主要的 chart values 如下:** 

loki chart values
```
loki:
  auth_enabled: true
  tenants:  
    - name: company  
      password: company@2020
gateway:
  enabled: true
  username: null # loki.tenants 的值可以覆盖此处，并在模板中正确渲染生效；反之不可以
  password: null 
```

promtail chart values
```
clients:
  - url: http://loki-gateway/loki/api/v1/push
    basic_auth:
      password: company@2020
      username: company
```

- 已经创建的 loki-promtail 的 config secret
```
server:
  log_level: info
  log_format: logfmt
  http_listen_port: 3101
  

clients:
  - basic_auth:
      password: company@2020
      username: company
    url: http://loki-gateway/loki/api/v1/push

positions:
  filename: /run/promtail/positions.yaml

scrape_configs:
  # See also https://github.com/grafana/loki/blob/master/production/ksonnet/promtail/scrape_config.libsonnet for reference
  - job_name: kubernetes-pods
    pipeline_stages:
      - cri: {}
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels:
          - __meta_kubernetes_pod_controller_name
        regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
        action: replace
        target_label: __tmp_controller_name
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_name
          - __meta_kubernetes_pod_label_app
          - __tmp_controller_name
          - __meta_kubernetes_pod_name
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: app
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_instance
          - __meta_kubernetes_pod_label_instance
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: instance
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_component
          - __meta_kubernetes_pod_label_component
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: component
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node_name
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - namespace
        - app
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - action: replace
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
      - action: replace
        regex: true/(.*)
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_annotationpresent_kubernetes_io_config_hash
        - __meta_kubernetes_pod_annotation_kubernetes_io_config_hash
        - __meta_kubernetes_pod_container_name
        target_label: __path__
  
limits_config:

tracing:
  enabled: false
```

## Promtail Running on VM

主要需求日志目标源: 

| 基础 | path |  |  | 特有 | path |  |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| auth.log | /var/log/auth.log | done |  | Docker | unix:///var/run/docker.sock | done |
| syslog | /var/log/syslog | done |  | Nginx | /var/log/nginx/**.log | done |
| kern.log | /var/log/kern.log | done |  | Postgresql | /var/log/postgresql/**.log | done |
| apt | /var/log/apt/**.log | done |  | MinIO |  |  |
| journal | /var/log/journal | done |  | Clickhouse | /var/log/clickhouse-server/**.log | u: clickhouse |
|  |  |  |  | Bastillion | app/Bastillion-jetty/jetty/logs/**.jetty.log | u: company |
|  |  |  |  | MySQL | /var/log/mysql/**.log |  |
|  |  |  |  | ZooKeeper | 需要特别配置 |  |
|  |  |  |  | Redis | /var/log/redis/redis-server.log |  |
|  |  |  |  | Kafka | 安装路径/logs/**.log | u: company |
|  |  |  |  | Etcd | 需要特别配置 |  |
|  |  |  |  | RKE2 | /var/lib/rancher/rke2/agent/logs/kubelet.log<br>/var/lib/rancher/rke2/agent/containerd/containerd.log | u: root |

### Debug

>[!error]
> agent 运行但无法读取目标文件
```
Jun 24 18:34:12 test-sys-lab-09 promtail[381246]: level=warn ts=2024-06-24T10:34:12.260671854Z caller=promtail.go:263 msg="enable watchConfig"
Jun 24 18:34:17 test-sys-lab-09 promtail[381246]: level=info ts=2024-06-24T10:34:17.259860066Z caller=filetargetmanager.go:372 msg="Adding target" key="/var/log/syslog:{job=\"syslogs\"}"
Jun 24 18:34:17 test-sys-lab-09 promtail[381246]: level=info ts=2024-06-24T10:34:17.259951353Z caller=filetarget.go:313 msg="watching new directory" directory=/var/log
Jun 24 18:34:17 test-sys-lab-09 promtail[381246]: level=error ts=2024-06-24T10:34:17.260001749Z caller=filetarget.go:385 msg="failed to start tailer" error="open /var/log/syslog: permission denied" filename=/var/log/syslog
Jun 24 18:34:27 test-sys-lab-09 promtail[381246]: level=error ts=2024-06-24T10:34:27.260842577Z caller=filetarget.go:385 msg="failed to start tailer" error="open /var/log/syslog: permission denied" filename=/var/log/syslog
```

>[!solution] 
>保证其加入 adm 组（查看的文件都在 adm 组中）
```bash
-rw-r-----   1 syslog    adm               25031 Jun 25 10:58 auth.log
-rw-r-----   1 syslog    adm               39744 Jun 22 23:17 auth.log.1
-rw-r-----   1 syslog    adm                2059 Jun 15 23:17 auth.log.2.gz
-rw-r-----   1 syslog    adm                2044 Jun  8 23:17 auth.log.3.gz
-rw-r-----   1 syslog    adm                2041 Jun  1 23:17 auth.log.4.gz
```

>[!error] 
> 404发送失败
```bash
<pre>Jun 25 10:58:22 test-sys-lab-09 promtail[389765]: level=info ts=2024-06-25T02:58:22.461246121Z caller=tailer.go:147 component=tailer msg=&quot;tail routine: started&quot; path=/var/log/syslog
Jun 25 10:58:23 test-sys-lab-09 promtail[389765]: level=error ts=2024-06-25T02:58:23.56377309Z caller=client.go:430 component=client host=loki.testlab.net msg=&quot;final error sending batch&quot; status=404 tenant= error=&quot;server returned HTTP status 404 Not Found (404): &quot;
Jun 25 10:58:24 test-sys-lab-09 promtail[389765]: level=error ts=2024-06-25T02:58:24.762775766Z caller=client.go:430 component=client host=loki.testlab.net msg=&quot;final error sending batch&quot; status=404 tenant= error=&quot;server returned HTTP status 404 Not Found (404): &quot;
Jun 25 10:58:26 test-sys-lab-09 promtail[389765]: level=error ts=2024-06-25T02:58:26.062618043Z caller=client.go:430 component=client host=loki.testlab.net msg=&quot;final error sending batch&quot; status=404 tenant= error=&quot;server returned HTTP status 404 Not Found (404): &quot;</pre>
```

>[!solution]
>此处 url 应该指定的是 `loki-write`

### docker logging

#### 允许连接 docker.sock
`sudo usermod -aG docker promtail`

**配置内容：**
```
server:
  http_listen_port: 9080
  grpc_listen_port: 0

# 保存日志文件的读取偏移量
positions:
  filename: /tmp/positions.yaml


# loki 的联系地址
clients:
  - url: http://loki.testlab.net/loki/api/v1/push #此处是loki-write
    basic_auth:
      username: company
      password: company@2020
    tenant_id: company

scrape_configs:
  - job_name: flog_scrape
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
```

[docker_sd_configs reference](https://community.grafana.com/t/promtail-does-not-collect-logs-from-other-containers/87000)

**报错**
```
st=loki.testlab.net msg="final error sending batch" status=400 tenant=company error="server returned HTTP status 400 Bad Request (400): 5 errors like: entry for stream '{container=\"minio\", service_name=\"minio\"}' has timestamp too old: 2024-06-14T10:25:30Z, oldest acceptable time>
```

>[!solution]
>loki 的配置项:
>```
>limits_config:  
>  reject_old_samples: false  # 是否拒绝过时的样本
>  reject_old_samples_max_age: 168h  # 过时的判断标准，最大时长7天


#### 尝试 pipeline_stages
```
  - job_name: docker
    pipeline_stages:
      - docker: {}
    static_configs:
      - targets:
          - localhost
        labels:
          vm: docker
          host: 10.1.0.81
          __path__: /var/lib/docker/containers/**/*-json.log
```
未成功，无任何报错，欠缺：即使成功发送日志也需要进一步处理得到容器名等。当前 sd config 更适用。

后续需要对做更多的 pip 的研究


### 正常的完整配置文件
```yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

# 保存日志文件的读取偏移量
positions:
  filename: /tmp/positions.yaml

# loki 的联系地址
clients:
  - url: http://loki.testlab.net/loki/api/v1/push #此处是loki-write
    basic_auth:
      username: company
      password: company@2020
    tenant_id: company  #必须指定（但k8s的pod中配置文件反而没有这个配置项，却没有报错，很奇怪。难道是gateway路由时传递了这个id？）

scrape_configs:
  - job_name: journal
    journal:
      labels:
        host: 10.8.0.89
        system: journal
      path: /var/log/journal/
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
      - source_labels: ['__journal_priority_keyword']
        target_label: 'level'
      - source_labels: ['__journal_syslog_identifier']
        target_label: 'syslog_identifier'
  - job_name: docker_scrape
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [ '__meta_docker_container_name' ]
        regex: '/(.*)'
        target_label: 'container'
    static_configs:
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09

  - job_name: system
    static_configs:
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          system: syslog
          __path__: /var/log/syslog
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          system: authlog
          __path__: /var/log/auth.log
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          system: kernlog
          __path__: /var/log/kern.log
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          system: aptlog
          __path__: /var/log/apt/**.log

  - job_name: service
    static_configs:
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          service: nginx
          __path__: /var/log/nginx/**.log
      - labels:
          host: 10.8.0.89
          hostname: test-sys-lab-09
          service: postgresql
          __path__: /var/log/postgresql/**.log
```

## Ansible Template
- templates/config.yml.j2
```
server:  
  http_listen_port: 9080  
  grpc_listen_port: 0  
  
# 保存日志文件的读取偏移量  
positions:  
  filename: "{{ app_service }}/promtail/data/positions.yaml"  
  
clients:  
  - url: "https://{{loki_url}}/loki/api/v1/push"  
    basic_auth:  
      username: "{{ ansible_user }}"  
      password: "{{ ansible_ssh_pass }}"  
    tenant_id: "{{ ansible_user }}"  
  
scrape_configs:  
  - job_name: journal  
    journal:  
      labels:  
        host: {{ ansible_host }}  
        system: journal  
      path: /var/log/journal/  
    relabel_configs:  
      - source_labels: ['__journal__systemd_unit']  
        target_label: 'unit'  
      - source_labels: ['__journal__hostname']  
        target_label: 'hostname'  
      - source_labels: ['__journal_priority_keyword']  
        target_label: 'level'  
      - source_labels: ['__journal_syslog_identifier']  
        target_label: 'syslog_identifier'  
  - job_name: docker_scrape  
    docker_sd_configs:  
      - host: unix:///var/run/docker.sock  
    relabel_configs:  
      - source_labels: [ '__meta_docker_container_name' ]  
        regex: '/(.*)'  
        target_label: 'container'  
    static_configs:  
      - labels:  
          host: {{ ansible_host }}  
          hostname: {{ ansible_hostname }}  
  
{% for category, paths in labels.items() %}  
  
  - job_name: {{ category }}  
    static_configs:  
{% for target_label, target_path in paths.items() %}  
      - labels:  
          host: {{ ansible_host }}  
          hostname: {{ ansible_hostname }}  
          {{ category }}: {{ target_label }}  
          __path__: {{ target_path }}  
{% endfor %}  
{% endfor %}
```

- vars/main.yml
```
version: '3.0.0'  
# loki-write 的地址（只需要写）  
loki_url: "loki.testlab.net"  

# design for vm server logs  
labels:
  system:
    syslog: /var/log/syslog
    authlog: /var/log/auth.log 
    kernlog: /var/log/kern.log  
    aptlog: /var/log/apt/**.log  
  service:  
    nginx: /var/log/nginx/**.log  
    postgresql: /var/log/postgresql/**.log
```


