---
title: metrics
author: LC
toc: true
date: 2024-05-24 11:59:45
img:
top:
cover:
password:
summary: nextcloud 在云原生的指标暴露测试
categories: Kubernetes
tags: ['kubernetes', 'nextcloud', 'metrics']
---

### 1. 步骤
### 1 .1 生成一个 token，并填写在 values.metrics.token

```bash
openssl rand -hex 32 # 生成token
```

- 在不同的版本下，可能存在并未启用 tokenkey，将导致 nextcloud-metrics template 渲染时缺少一个变量

```yaml
.values.nextcloud.existingSecret.tokenKey: nextcloud-token
# 确保此处未被注释
```

### 1.2 为 exporter 设置 trusted_domains, 在集群中，metrics-exporter (nextcloud-metrics.nextcloud.svc.cluster.local)直接访问 nextcloud 实例前，需要被信任

- nextcloud.configs----for trusted_domains
```yaml
  configs:
    domains.config.php: |-
      <?php
      $CONFIG = array (
        'trusted_domains' =>
          array (
           0 => 'localhost',
           1 => 'nextcloud-metrics.nextcloud.svc.cluster.local',  # 原理上，这里生效即可，但是这个实际却没有作用，因为是在nextcloud的配置中，所以不遵从k8s网络规则
           2 => '*',                                              # 仅此处生效，10.0.0.0/8 不生效
          )
      );
```

### 1.3 安装成功后，在终端让 nextcloud-server 通过 occ  命令做 token 设置

```bash
#使用上方已经生成的token

kubectl -n nextcloud exec nextcloud-86465f6d56-gcz6b -- su -s /bin/sh www-data -c "php occ config:app:set serverinfo token --value 9077a6605148d99de4f1dc6adaa30ad32ad406d7ef434b4abd8e7f8999a2ea2c" # server设置 token
```

### 1.4 nextcloud-metrics 此时应该能够拿到有关指标，并转换格式

- 在集群内使用 curl 
```bash
curl http://nextcloud-metrics:9205/metrics   # 得到指标
```
### 2. debug
>[!error]
>msg="Error during scrape: Get \" http://nextcloud.nextcloud.svc.cluster.local:8080/ocs/v2.php/apps/serverinfo/api/v1/info?format=json\": dial tcp 10.43.173.56:8080: connect: connection refused" \
>level=error msg="Error during scrape: unexpected status code: 400"

>[!solution]
>原因：trusted_domains 没有设置 信任源地址

#### 查看已经设置的 trusted_domains
```
kubectl -n nextcloud exec nextcloud-c96bdff98-kbftk -- su -s /bin/sh www-data -c "php occ config:system:get trusted_domains"

  localhost
  *.nextcloud.svc.cluster.local
  *
```

>[!error] 
>表现：此时的 nextcloud_up=0，指标未正确收集 \
>Error during scrape: Get \" https://nextcloud:8080/ocs/v2.php/apps/serverinfo/api/v1/info?format=json\": http: server gave HTTP response to HTTPS client" 


>[!Solution]
>声明 .values.metrics.https: false 

>[!error] 
>表现：此时的 nextcloud_up=0，指标未正确收集 \
>"Error during scrape: Get \" http://nextcloud:8080/ocs/v2.php/apps/serverinfo/api/v1/info?format=json\": context deadline exceeded (Client.Timeout exceeded while awaiting headers)"

>[!Solution]
>此时经过实践，更换 exporter 的镜像之后升级应用可以解决这个问题，原因未明。


### 3. Prometheus 通过 endpoints 抓取指标
此时应用的 nextcloud-metrics 的 service 具有 scrape 的 annotations，可以正常获取指标



