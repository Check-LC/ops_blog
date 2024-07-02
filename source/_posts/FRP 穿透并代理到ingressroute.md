---
title: FRP 穿透并代理到ingressroute
date: 2024-04-16 10:02:00
tags: [FRP, IngressRoute]
categories: Ops
summary: 公网访问家中的试验虚拟机上的kube集群
---

条件：需要有一个公网中的主机，如果需要通过域名进行 http 类型的穿透，需要有域名。
说明：没有 ssl 证书，所以都是基于 http 的尝试，后续补充 https。
## 服务端配置
### frps .toml 基本如此，没有特殊需要将不会改
github 仓库中有一个目录是 conf，其中可以看到所有的配置和注解
```toml
bindPort = 7000
bindAddr = "my PublicIP"
vhostHTTPPort = 8080  # 使用 Http 类型的代理穿透时需要增加此端口
auth.method = "token"
auth.token = "domainMyDomainname" # 自定义即可

subDomainHost = "MyDomainname.cn"  # 配合 client 端的 subdomain 使用。
```
### systemd 管理服务
```bash
[root@oncloud html]# cat /usr/lib/systemd/system/frps.service
[Unit]
# 服务名称，可自定义
Description = frp server
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
# 启动frps的命令，需修改为您的frps的安装路径
ExecStart = /usr/local/bin/frps -c /etc/frp/frps.toml

[Install]
WantedBy = multi-user.target
```

```
sudo systemctl daemon-reload
sudo systemctl enable --now frps
```

因为是使用 http 类型，还给公网的这个机器做了 nginx 代理
### nginx 代理配置文件
```nginx.conf
server {
        listen 80;
        server_name rancher.MyDomainname.cn;

        location / {
            proxy_pass http://my PublicIP:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
}
```

## 客户端使用
同样可以使用 systemd 管理 frpc 服务
### 案例 1：ssh 连接内网主机

#### frpc .toml 
```toml
serverAddr = "my PublicIP"
serverPort = 7000
auth.method = "token"
auth.token = "domainMyDomainname"

[[proxies]]    # 固定
name = "ssh"   # 自定义，唯一，相当于这个配置块的名称
type = "tcp"
localIP = "127.0.0.1"  #主要是需要监听到子网这个主机的ipv4地址
localPort = 22         # 子网这个主机的 ssh 端口
remotePort = 6000     # 配置后，公网主机将自行监听此端口
```
#### 使用
 `ssh -o Port=6000 子网机器 user 名@公网主机名`  \
 效果：在 WLAN 主机执行后，6000-->7000-->subnet `
### 案例 2：自定义域名访问内网服务
#### frpc .toml
```toml
serverAddr = "my PublicIP"
serverPort = 7000
auth.method = "token"
auth.token = "domainMyDomainname"

[[proxies]]
name = "test1-web"
type = "http"
localIP = "192.168.3.20"  # 内网Nginx
localPort = 80            # ip + port，相当于将frpserver的流量定向到这个内网的地址，在此例中，这个地址是nginx，所以会再指向它代理的地址
subdomain = "rancher"  # 配合 server 端的配置，组成域名rancher.MyDomainname.cn；这时在公网中需要给自己域名增加的一个解析
hostHeaderRewrite = "master.MyDomainname.cn" # 会将 subdoamin 组成的host会替换为此配置，以后可以只在域名解析使用以上一个A记录就好
```

>[!annotation]
>基于上述配置，我在自己的内网中还有 dns 和 nginx 配合使用，子网主机都使用内网 DNS。

DNS 中使用的域名是 testlab.net；解析记录主要是内网中的服务。
Nginx 使用：http 穿透后，流量会到我的 nginx 80 端口，然后配置一个代理转发，流量将去向真正的服务的地址（DNS 需要做好目标的解析）。
#### nginx proxy example
```nginx.conf
server {
    listen 80;
    server_name master.MyDomainname.cn;

    location / {
        proxy_pass http://master.homelab.net;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

基于这个客户端配置，我在公网访问 rancher.MyDomainname.cn 就将能够访问子网中的，master.homelab.net 的服务（这是一个普通的web）
流量：
```
desktop--> rancher.MyDomainname.cn --> External DNS --> Server under WLAN --> nginx --> frps --> frpc --> nginx proxy --> internal nginx --> target service
```

### 案例 3：内网中 nginx 代理 traefikingressrout（区别于普通web）
#### frpc .toml
```toml
serverAddr = "my PublicIP"
serverPort = 7000
auth.method = "token"
auth.token = "domainMyDomainname"

[[proxies]]
name = "test2-web"
type = "http"
localIP = "192.168.3.20"
localPort = 80
subdomain = "rancher"
```

#### nginx proxy example
```nginx.conf
server {
    listen 80;
    server_name rancher.MyDomainname.cn;

    location / {
        proxy_pass http://rancher.homelab.net;
        proxy_set_header Host rancher.homelab.net;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

>[! failure] 
>上述测试出现不能成功转发，甚至不是 404。而且直接在浏览器地址栏显示代理后的 rancher. Homelab. Net；无论是否配置 Host 变量，无论这个
>Host 是使用$host 或者是静态的 `rancher.homelab.net`

#### 单独测试 nginx 代理 ingressroute
这个是在公司内网，仅测试 nginx 转发到 traefik ingressroute 的配置，成功访问。但是在家中的环境下仍然不能成功访问。
```nginx.conf
server {
    listen 80;
    server_name rancher.MyDomainname.cn;

    location / {
        proxy_pass http://monitorprom.testlab.net;
        proxy_set_header Host monitorprom.testlab.net;   # 原以为此配置很重要，不然经 nginx 转发后的请求host header不正确（可测试发现配置与否都成功实现代理了）
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 测试效果
![nginx转发到traefik ingressroute 的效果](https://ice.frostsky.com/2024/04/16/c8572ce35380b5e78eb2895579f6573b.png)

#### 成功穿透下的配置
frpc 没有变化，nginx 如下
```nginx.conf
server {
    listen 80;
    server_name rancher.MyDomainname.cn;

    location / {
        proxy_pass https://rancher.homelab.net;  # 原使用的是http，或许家中的集群配置了traefik 使用tls，待验证
        proxy_set_header Host rancher.homelab.net; # 此项配置不影响
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
