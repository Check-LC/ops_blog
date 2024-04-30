---
title: cert-manager
author: LC
toc: true
date: 2024-04-30 23:15:54
img:
top: true
cover:
password:
summary: 尝试使用 cert-manger 自动签发权威证书的尝试
categories: kubernetes
tags: [cert-manager]
---
## Prepare
首先装上 crds，使用的 kubectl 安装。不建议在 helm 中使用 crd: enable, 这样升级 cert-manager 的时候，随 helm 的卸载和升级，集群中已经有的自定义资源会消失。(官网有特别说明这两种安装方式的不同)
##  helm install cert-manager

### helm metrics
```
prometheus:
  enabled: true
  servicemonitor:
    enabled: true  # 没有配置servicemonitor，使用已配置的服务自动发现也可以获取指标。
```

>[!question]
>确实只有三条指标吗？----a issue in repo 提到：当存在有证书资源的时候就会有更多指标存在
>```
># HELP certmanager_clock_time_seconds DEPRECATED: use clock_time_seconds_gauge instead. The clock time given in seconds (from 1970/01/01 UTC).
># TYPE certmanager_clock_time_seconds counter
certmanager_clock_time_seconds 1.713170784e+09
># HELP certmanager_clock_time_seconds_gauge The clock time given in seconds (from 1970/01/01 UTC).
># TYPE certmanager_clock_time_seconds_gauge gauge
certmanager_clock_time_seconds_gauge 1.713170784e+09
># HELP certmanager_controller_sync_call_count The number of sync() calls made by a controller.
># TYPE certmanager_controller_sync_call_count counter
certmanager_controller_sync_call_count{controller="ingress-shim"} 5
>```

## 简单使用并验证指标数量
### 域名和阿里 dns 赋权用户
[01_域名管理](domain-management.md) \

#### RAM 用户权限

目的：在 cert-manager 中使用 lets encrypt 通过 alidns 的 webhook 来创建证书。 需要：创建一个子用户
在 RAM 访问控制台创建一个用户，给予 api 访问即可，创建后点击用户，编辑授权。

![28b2ee3eedfdf53267a55dd203fc3972.png](https://i.mji.rip/2024/04/30/28b2ee3eedfdf53267a55dd203fc3972.png)

### alidns-webhook

> 介绍
>ACME（Automatic Certificate Management Environment）是一个用于自动化从证书颁发机构（Certificate Authority, CA）获取、续签和吊销 SSL/TLS 证书的协议。ACME 旨在简化证书管理过程，使得网站管理员可以轻松地为其网站启用 HTTPS 加密，从而提高网络安全性。
>
>>Cert Manager 使用 DNS01 验证来自动化地获取和续订由 ACME 服务器（如 Let's Encrypt）颁发的 SSL/TLS 证书。DNS01 要求 Cert Manager 能够创建和删除 DNS TXT 记录，以证明域名的所有权。由此，Cert Manager 需要与 DNS 服务提供商的 API 进行交互。
>
>>这就是为什么需要像 alidns 的 webhook 这样的组件。Webhook 解析器是 Cert Manager 中的一种机制，它允许开发者创建自定义的逻辑来处理 DNS01 挑战。这些 webhook 解析器作为独立的服务运行，并且能够接收来自 Cert Manager 的 DNS01 验证请求，并执行必要的操作来满足的要求。
>
> Webhook 的作用
>
>>当使用 Cert Manager 与具体的 DNS 服务（如 AliDNS）交互时，需要一种方式来自动化更新 DNS 记录的过程。这就是 webhook 发挥作用的地方：
>>
>>1. **自动化处理**：Webhook 提供了一种机制，通过这种机制 Cert Manager 可以自动向 DNS 提供商请求添加、修改或删除 DNS 记录。这对于自动化证书的申请、续期和撤销过程至关重要。
>>
>>2. **安全访问**：通过 webhook，可以安全地集成第三方服务（如 DNS 提供商），同时遵守最小权限原则。Webhook 通常需要配置相应的 API 凭证，这些凭证应当只赋予修改 DNS 记录所需的权限，从而降低安全风险。
>>
>>3. **提供商特定的逻辑**：不同的 DNS 提供商可能有不同的 API 接口和规则。Webhook 可以封装这些特定的逻辑，使得 Cert Manager 能够以统一的方式处理不同 DNS 提供商的接口。
>
>实现细节
>
>>例如，在使用AliDNS的场景中，Cert Manager需要一个AliDNS webhook来处理DNS记录的修改。这个webhook负责与AliDNS的API进行交互，执行如下操作：
>>
>> - 当 Cert Manager 需要在 DNS 中创建一个新的 TXT 记录以响应 DNS-01挑战时，webhook 将调用 AliDNS 的 API 来添加该记录。
>> - 完成验证后，webhook 将再次调用 API 删除该 TXT 记录，以清理不再需要的记录。
>
>通过这种方式，Cert Manager可以实现完全自动化的证书管理，无需人工干预DNS记录的更新，大大简化了使用SSL/TLS证书的复杂性。
>总的来说，alidns 的 webhook 为 Cert Manager 提供了与阿里云 DNS 服务交互的能力，使得 Cert Manager 能够自动化地完成 DNS01 挑战，从而简化了在 Kubernetes 集群中管理 SSL/TLS 证书的过程。

#### 安装 alidns-webhook (两种webhook)
- helm（本例使用）
- reference： [GitHub - DEVmachine-fr/cert-manager-alidns-webhook: Cert-manager webhook to generate Let's Encrypt certificates over Alibaba Cloud DNS.](https://github.com/DEVmachine-fr/cert-manager-alidns-webhook)
```shell
  # 部署 阿里云 DNS Webhook，groupName的值修改为自己的域名
  helm repo add cert-manager-alidns-webhook https://devmachine-fr.github.io/cert-manager-alidns-webhook
  helm repo update
  helm upgrade -i alidns-webhook cert-manager-alidns-webhook/alidns-webhook \
    --set groupName=acme.chaoslong.cn
```

- 另一个 manifest 文件安装（使用有不同）
```bash
wget https://raw.githubusercontent.com/pragkent/alidns-webhook/master/deploy/bundle.yaml

# 修改文件中的acme.yourcompany.com为自己的域名
sed -i s/'acme.yourcompany.com'/'acme.chaoslong.cn'/g bundle.yaml
```

### Secret of AliDNS Access
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alidns-secret
  namespace: cert-manager
type: Opaque
data:
  accesskey-id: xxxxxxxxxxxxxxxx  # echo -n "shdhd" | base64 ; echo -n 参数没换行符输出
  accesskey-secret: xxxxxxxxxxxx

或者

kubectl create secret generic alidns-secrets --from-literal="access-token=xxxxxxx" --from-literal="secret-key=xxxxxxxxxx"
```
### Create Letsencrypt clusterissuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    # Change to your letsencrypt email
    email: chao.long@inboc.net
    # 测试阶段可以用 staging （无限制）
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # 正式
    # server: https://acme-v02.api.letsencrypt.org/directory 
    privateKeySecretRef:
      name: letsencrypt-staging-acme-count # 如果不存在将创建，用以存放一个私钥，作为 ACME 账户的私钥，用于与 ACME 服务器进行安全通信
    solvers:
    - dns01:
        webhook:
          groupName: chaoslong.cn  #同于webhook安装中的值
          solverName: alidns   # 固定
          config:
            region: ""
            secretKeySecretRef:
              name: alidns-secret
              key: accesskey-id
            accessTokenSecretRef:
              name: alidns-secret
              key: accesskey-secret
    selector：    # 当 cert-manager 处理证书请求时，它将只为这些 DNS 区域中的域名创建和更新 DNS 记录。
      dnsZones:
      - 'mydomdom.org'
      - '*.mydomdom.org'
```

手动生成证书
`certificates` -> `certificaterequests` -> `orders` -> `challenges`.
```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: chaoslong-test-tls
  # 指定证书生成到哪个工作空间，不指定也可以
  namespace: cert-manager
spec:
  #生成后证书的secret名称
  secretName: chaoslong-test-tls
  duration: 24h
  # 指定域名
  dnsNames:
  - "chaoslong.cn"
  - "*.chaoslong.cn"
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
```

> [!debug]
>  此时以上各种新增资源一直是 pending 或者 unavailable; accesskey 解析一直失败\
>  排查发现：
>  ```
>  - dns01:
>          webhook: 
>            config: 
>              accessTokenSecretRef:     # 此处书写错误，使用了另一个 webhook 的变量，正确的如此配置
>                key: access-token        # 这是 asccesskey 的 id
>                name: alidns-secrets 
>              region: '' 
>              secretKeySecretRef:
>                key: secret-key      # 这是 accesskey 的 secert
>                name: alidns-secrets  
>```
>certmanager 如果成功调用 webhook，会在证书验证过程中生成一个 challenge 的 TXT 记录到 DNS，判断域名的所有权\

>[!success] Valid 描述 
>创建 certificates 资源之后，challenges 和 orders 会相应生成，在验证过程中会有一段较长的时间等待世界 DNS 缓存刷新（会生成一个 cert.doamin.cn）。
最终状态正常之后，challenges 删除，其 txt 记录也会被删除，存放证书内容的 tls-secret 状态将变为合法，其中会存储有证书内容。


## 待尝试
## Vault 保存证书

## 应用通过 ESO 请求证书