---
title: The First time using Helm Charts
date: 2023-12-04 18:50:57
tags:
  - helm
categories:
  - Kubernetes
summary: The first time using Helm Charts to install serices.(Self-service-password,ldap-account-management)
---
## 一、ldap-account-manager
### 1.1 Repo URL
- https://gabibbo97.github.io/charts/
### 1.2 Values Modify----values.yaml
```
extraEnv:
  LAM_SKIP_PRECONFIGURE: false
  LDAP_DOMAIN: example.net;ibswufe.com
  LDAP_BASE_DN: dc=example,dc=net;dc=ibswufe,dc=com
  LDAP_SERVER: ldaps://ldap01.example.net
  LDAP_USER: cn=administrator,dc=example,dc=net
  LAM_LANG: zh_CN
  LAM_PASSWORD: lam
```

## 二、 self-service-password
### 2.1 Repo URL
- https://ygqygq2.github.io/charts/
- Set image tag:5.3.3 to pull the latest one
### 2.2 Charts Using
#### 2.2.1 ENV Setting ConfigMap
- So confused about why cannot make it effective when I  using  the ConfigMap settings In the values.yaml to  cover the default php configurations of this soft.
- So that , Using a ConfigMap Data to  define the container environment variables of this chart.
- env-config.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
name: self-service-password-env
data:
    USE_QUESTIONS: 'false'
	LDAP_BINDDN: "cn=exampleadmin,dc=example,dc=net"
	SECRETEKEY: "example"
	DEFAULT_ACTION: "sendtoken"
	LANG: "cn,zh-CN"
	IS_BEHIND_PROXY: 'true'
	SITE_URL: "https://ssp.example.net/index.php"
	LDAP_SERVER: "ldap://10.13.3.107"
	LDAP_BASE_SEARCH: "ou=example,dc=example,dc=net"
	LDAP_LOGIN_ATTRIBUTE: "cn"
	LOGO: images/mnt/ltb-logo.png                                  # 共享存储，挂载在容器中的/www/ssp/images/mnt
	BACKGROUND_IMAGE: images/mnt/background.jpg
	MAIL_FROM_NAME: "密码自主修改服务"
	MAIL_SIGNATURE: "如有疑问,请联系运维同事,英博智云."
	MAIL_USE_LDAP: 'true'
	NOTIFY_ON_CHANGE: 'true'
	SMTP_AUTH_ON: 'true'
	SMTP_HOST: "smtphz.qiye.163.com"
	MAIL_FROM: "chao.long@example.net"
	SMTP_USER: "chao.long@example.net"
	SMTP_SECURE_TYPE: 'ssl'
	SMTP_PORT: '465'
	SMTP_AUTOTLS: 'false'
	PASSWORD_DIFFERENT_LOGIN: 'true'
	PASSWORD_MAX_LENGTH: '30'
	PASSWORD_MIN_LENGTH: '8'
	PASSWORD_MIN_LOWERCASE: '1'
	PASSWORD_MIN_SPECIAL: '1'
	PASSWORD_MIN_UPPERCASE: '1'
	PASSWORD_COMPLEXITY: '4'
	PASSWORD_NO_REUSE: "true"
	PASSWORD_SHOW_POLICY: "always"
	PASSWORD_SPECIAL_CHARACTERS: "^a-zA-Z0-9"
```

- add a field `envFrom`  under the `env` in templates/deployment-statefulset.yaml
```
env:
{{ toYaml .Values.env | indent 12 }}
envFrom:
- configMapRef:
    name: self-service-password-env
```
#### 2.2.2 Secret
- there are two variables need to been encrypted
- values.secret
```
secret:
  enabled: true
  mountPath: /etc/secret-volume
  subPath: ""
  readOnly: true
  data:
    ldap_bindpass: "example@2020"
    smtp_pass: "WaLxeu3pvsQaqd7X"
```
#### 2.2.3 values.env
```
env:
  - name: LDAP_BINDPASS
    valueFrom:
      secretKeyRef:
        name: self-service-password
        key: ldap_bindpass
  - name: SMTP_PASS
    valueFrom:
      secretKeyRef:
        name: self-service-password
        key: smtp_pass
```

#### 2.2.4 persistentVolume 
- create  pv & pvc resources under this namespace，mount the volume ，name: self-service-password
```
persistentVolume:   # 是否存储持久化
  enabled: true
  storageClass: "-"
  accessMode: ReadWriteOnce
  annotations: {}
  size: 1Gi  # 大小
  existingClaim: {}  # 使用已存在的pvc
  mountPaths:
   - name: data-storage
     mountPath: /www/ssp/images/mnt  # 容器内路径，将新建 mnt
     subPath: ssp-nfs                               # pv 中挂载点下的子目录
```

- pv.yaml
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: self-service-password
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /home/example/nfs # 指定nfs的挂载点
    server: 10.13.3.108
```

- Post  test，reverse proxy by nginx using Nodeport。Setting the dns resolving，take a visit of this site。
```
upstream ssp {
  server 10.13.3.109:32337;
}
server {
    listen 80;
    server_name ssp.example.net;
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl ;
    server_name ssp.example.net;
    ssl_certificate tls/tls_ca.pem; 
    ssl_certificate_key tls/tls_key.pem;
    location / {
      proxy_pass http://ssp;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto "https";
      proxy_read_timeout 1800s;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    }
}
```
### 三、To Do List
Learn more about：
- storage
- traefik