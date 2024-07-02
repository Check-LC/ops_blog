---
title: helm install loki
author: LC
toc: true
date: 2024-07-02 21:26:41
img: https://ice.frostsky.com/2024/07/02/a44a28f2666994b1f0e23c35acee8043.png
top: false
cover:
password:
summary: 记录在集群中部署 loki 的踩坑过程
categories: OpenTelemetry
tags: ['loki', 'Log']
---

## Simple Scalable Mode

Loki chat version： v6.6.3 ; Application version: 3.0.0 \
Promtail chat version: v6.16.0 ; Application version: v3.0.0 \
Architecture：With memcached & backend

### Debug

#### 读写节点报错
#####  s3 的连接

>[!solution]
>reference1 [Helm Chart cannot parse environment variables with "- config.extra-env=true" · Issue #12218 · grafana/loki · GitHub]( https://github.com/grafana/loki/issues/12218 ) \
>reference2 [How to configure aws s3 credentials securely for accessing aws storage object in loki-configuration · Issue #8572 · grafana/loki · GitHub](https://github.com/grafana/loki/issues/8572) \
>声明变量引用的 s3 部分配置
> ```
>   storage:
>    # Loki requires a bucket for chunks and the ruler. GEL requires a third bucket for the admin API.
>    # Please provide these values if you are using object storage.
>    bucketNames:
>      chunks: loki
>      ruler: loki
>      admin: loki
>    type: s3
>    s3:
>      s3: "s3://loki"
>      endpoint: "http://10.1.0.81:9001/"
>      region: null
>      secretAccessKey: ${SECRETKEY}
>      accessKeyId: ${ACCESSID}
>      signatureVersion: v4
>      s3ForcePathStyle: true
> ```
>
>声明变量来源的 values(需要同时声明到 write、read、backend 下)\
> ```
>   extraArgs:  [-config.expand-env=true]
>   extraEnvFrom:
>    - secretRef:
>        name: loki-s3    
> ```
> 在此之前需要创建相应的 'secret' 资源，其键需要与变量名同

##### schemaConfig need quotes

>[! failure] 
>ailed parsing config: /etc/loki/config/config.yaml: parsing time "2024-06-18T00:00:00.000Z": extra text: "T00:00:00.000Z". 

>[!Solution]
>reference1 [\[loki-distributed\] Corrected date format by Sheikh-Abubaker · Pull Request #2731 · grafana/helm-charts · GitHub]( https://github.com/grafana/helm-charts/pull/2731 ) \
>在 schemaconfig 下的日期配置中需要将，日期的格式用双引号引用

#### Gatway 报错

>[!failure]
>gateway: \
>/docker-entrypoint.sh: No files found in /docker-entrypoint.d/, skipping configuration \
Tue, Jun 18 2024 3:04:19 pm2024/06/18 07:04:19 [emerg] 1 #1 : host not found in resolver "kube-dns.kube-system.svc.cluster.local." in /etc/nginx/nginx.conf:33 \
2024-06-18T15:04:19.969334333+08:00  nginx: [emerg] host not found in resolver "kube-dns.kube-system.svc.cluster.local." in /etc/nginx/nginx.conf:33 

>[!solution]
>gateway 日志中得出 helm 中存在应用关于 dns 部分的配置，在我们使用 rke2 创建的集群中，这个设置应该修改如下：\
>global.dnsService: "rke2-coredns-rke2-coredns"

#### backend
backend 出现有副本创建失败，原因是：longhorn 卷状态不正常

#### grafana 添加数据源

Loki 支持多租户，以使租户之间的数据完全分离。当 Loki 在多租户模式下运行时，所有数据（包括内存和长期存储中的数据）都由租户 ID 分区，该租户 ID 是从请求中的 `X-Scope-OrgID` HTTP 头中提取的。 当 Loki 不在多租户模式下时，将忽略 Header 头，并将租户 ID 设置为 `fake`，这将显示在索引和存储的块中。

==此为单租户的认证使用案例==

loki-gateway: 启用了认证，此处是相应的配置参考 

datasource congfig：Unable to fetch labels from Loki (Failed to call resource), please check the server logs for more details 

>[!solution]
>reference  [server returned HTTP status 401 Unauthorized (401): no org id · Issue #7081 · grafana/loki · GitHub](https://github.com/grafana/loki/issues/7081#issuecomment-1713478974)

Grafana 在 UI 的设置

config datasource.
> Auth:
> 
> > Basic auth: enable
> 
> Basic Auth Details:
> 
> > User: tenant-3  
> > Password: password-3
> 
> Custom HTTP Headers
> 
> > Header: `X-Scope-OrgID`  
> > Value: `tenant-3`

#### promtail 安装

两条重要日志：

grafana congfig: Data source connected, but no labels received. Verify that Loki and Promtail is configured properly. 

promtail log：level=error ts=2024-06-19t06:14:50.369753384z caller=client.go:430 component=client host=loki-gateway msg="final error sending batch" status=401 tenant= error="server returned http status 401 unauthorized (401): no org id"

#### **针对以上两条内容，主要的 chart values 如下:** 

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

## 新增 tenants 设置

目的：使用 rancher 特有的一个 question.yml 使用在 UI 填写租户名和密码，保证安全。但是最终没有成功实现，chart 的结构注定不能成功传入

目标数据：
```
tenants:
  - name: test
    password: test123  
```

- 这个枚举类型成功传递，但是没有意义 
```
categories:  
  - logging  
namespace: loki  
questions:  
  - variable: loki.tenants  
    label: Loki Tenants list  
    description: "Loki Tenants Set BY enum type"  
    group: "Loki Tenants"
type: enum  
options:  
  - - name: company  
      password: company@2020  
```

不能使用其他类型，程序将报错不能迭代，以下是`string`类型
```
Waiting for Kubernetes API to be available

Mon, Jun 24 2024 10:21:02 amhelm install --namespace=loki --timeout=10m0s --values=/home/shell/helm/values-loki-6.6.3.yaml --version=6.6.3 --wait=true loki /home/shell/helm/loki-6.6.3.tgz

Mon, Jun 24 2024 10:21:03 amError: INSTALLATION FAILED: template: loki/templates/gateway/secret-gateway.yaml:12:8: executing "loki/templates/gateway/secret-gateway.yaml" at <tpl .basicAuth.htpasswd $>: error calling tpl: error during tpl function execution for "{{ if .Values.loki.tenants }}\n {{- range $t := .Values.loki.tenants }}\n{{ htpasswd (required \"All tenants must have a 'name' set\" $t.name) (required \"All tenants must have a 'password' set\" $t.password) }}\n {{- end }}\n{{ else }} {{ htpasswd (required \"'gateway.basicAuth.username' is required\" .Values.gateway.basicAuth.username) (required \"'gateway.basicAuth.password' is required\" .Values.gateway.basicAuth.password) }} {{ end }}": template: loki/templates/gateway/secret-gateway.yaml:2:25: executing "loki/templates/gateway/secret-gateway.yaml" at <.Values.loki.tenants>: range can't iterate over [{name: 'company', password: 'company@2020'}]
```

对比
```
  tenants: []
  tenants: '[{name: ''company'', password: ''company@2020''}]'
```

secret 类型是选择一个当前名称空间已经存在的 secret 填入值中，适用场景 `envfrom ` .

## valut 拉取 minIO 的 access key

### ClusterSecretStore

通过 root token 的 vault 连接(测试，vault 用户管理更待学习)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: monitor-eso-loki-clustersecretstore
spec:
  provider:
    vault:
      server: "http://vault-internal.vault.svc.cluster.local:8200"
      version: "v2"
      path: "loki"
      auth:
        tokenSecretRef:
          name: "eso-vault-secret"
          namespace: "external-secrets"
          key: "vault-token"
```

###  ExternalSecret
```
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: monitor-eso-loki-s3-externalsecret
spec:
  refreshInterval: "12h"
  secretStoreRef:
    name: monitor-eso-loki-clustersecretstore
    kind: ClusterSecretStore
  data:
    - secretKey: ACCESSID
      remoteRef: 
        key: /loki-s3
        conversionStrategy: Unicode
        decodingStrategy: None
        metadataPolicy: None
        property: ACCESSID
    - secretKey: SECRETKEY
      remoteRef: 
        key: /loki-s3
        conversionStrategy: Unicode
        decodingStrategy: None
        metadataPolicy: None
        property: SECRETKEY
  target:
    creationPolicy: Owner
    deletionPolicy: Retain
    name: eso-loki-s3-secret
    template:
      type: Opaque
      data:
        ACCESSID: '{{ .ACCESSID }}'
        SECRETKEY: '{{ .SECRETKEY }}'
      engineVersion: v2
      mergePolicy: Replace 
```

附图，便于理解以上配置和 vault 中的路径与值的对应关系：
![454aba27238ef563199ef51ca9544f17.png](https://ice.frostsky.com/2024/07/02/454aba27238ef563199ef51ca9544f17.png)
