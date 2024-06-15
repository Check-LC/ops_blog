---
title: shadowsocks-libev
author: LC
toc: true
date: 2024-06-15 13:18:45
img:
top: true
cover: true
password:
summary: 为便于学习和测试时找到更多镜像资源和云原生资料，使用云主机建设个人用VPN
categories: VPN
tags: ['shadowsocks', 'vpn']
---

## 当前状况

使用 Mobaxterm 图形转发功能，在云主机创建 ssh 隧道，浏览器使用 proxy 插件连接本机的这个转发端口，以此实现访问 artifacthub、github 等

vmware workstation 中的其他虚拟机器使用的是下列命令

![笔记本代理转发虚拟机的网络](https://i3.mjj.rip/2024/06/15/a7a72b5d58cb6f24c77db493e4dc59ae.jpeg)


## 基本资料

- 个人云主机，ubuntu 2004
- shadowsocks-libev as server，也可以使用 `shadowsocks-qt5: Cross-platform client for Windows/MacOS/Linux`
- shadowsocks-win  as client

对比 openvpn，shadowsocks 确实更简单易用，个人使用已经足够，文档也比之更清晰

### shadowsocks 官方的文档介绍摘录

#### CLI implementations
- [shadowsocks](https://github.com/shadowsocks/shadowsocks): The original Python implementation.
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev): Lightweight C implementation for embedded devices and low end boxes. Very small footprint (several megabytes) for thousands of connections.
- [go-shadowsocks2](https://github.com/shadowsocks/go-shadowsocks2): Go implementation focusing on core features and code reusability.
- [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust): A rust port of shadowsocks.

[此处是官方讲解的 server 安装方式](https://shadowsocks.org/doc/deploying.html)

Feature comparison

|ss|ss-libev|go-ss2|ss-rust|
|:--:|:--:|:--:|:--:|
|TCP Fast Open|✓|✗|✓|
|Multiuser|✓|✓|✗|✓|
|Management API|✓|✓|✗|✓|
|Redirect mode|✗|✓|✓|✓|
|Tunnel mode|✓|✓|✓|✓|
|UDP Relay|✓|✓|✓|✓|
|MPTCP|✗|✓|✗|✓|
|AEAD ciphers|✓|✓|✓|✓|
|Plugin|✗|✓|✗|✓|
|Plugin UDP (Experimental)|✗|✗|✗|✓|

#### GUI Clients
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android): Android client.
- [shadowsocks-windows](https://github.com/shadowsocks/shadowsocks-csharp): Windows client.
- [shadowsocksX-NG](https://github.com/shadowsocks/ShadowsocksX-NG): MacOS client.
- [shadowsocks-qt5](https://github.com/shadowsocks/shadowsocks-android): Cross-platform client for Windows/MacOS/Linux.

## server 配置

### Ubuntu 配置文件

```json
cat /etc/shadowsocks-libev/config.json
{
    "server":["xxx.xxx.xxx.xxx"],   # 此处推荐填写公网IP或域名
    "mode":"tcp_only",              # 默认是tcp_and_udp
    "server_port":18388,            
    "local_port":11080,
    "password":"tejshf",       # 存在一个默认的连接密码，已修改
    "timeout":60,
    "method":"aes-256-gcm"     # 加密方式， The recommended choice is "chacha20-ietf-poly1305" or "aes-256-gcm"
}
```

### 重启与自启动
```bash
sudo systemctl restart shadowsocks-libev.service
sudo systemctl enable shadowsocks-libev.service  # 有点奇怪，不能正确添加 --now 参数，所以分别执行
sudo systemctl status shadowsocks-libev.service  # 确认状态
```

### Debug

下载客户端，在 win 和 android 连接时 分别报错 timeout、can’t resolve cp.cloudflare.com

### resolution

经回忆，发现是本机的防火墙未放行 server_port  `sudo ufw allow 18388/tcp`

### optimization (All official suggetions)

First of all, upgrade your Linux kernel to 3.5 or later.

#### Step 1, increase the maximum number of open file descriptors
To handle thousands of concurrent TCP connections, we should increase the limit of file descriptors opened.
Edit the `limits.conf`

```bash
vi /etc/security/limits.conf
```

Add these two lines

```
* soft nofile 51200
* hard nofile 51200

# for server running in root:
root soft nofile 51200
root hard nofile 51200
```

Then, before you start the shadowsocks server, set the ulimit first

```bash
ulimit -n 51200
```

#### Step 2, Tune the kernel parameters
The priciples of tuning parameters for shadowsocks are
1. Reuse ports and conections as soon as possible.
2. Enlarge the queues and buffers as large as possible.
3. Choose the TCP congestion algorithm for large latency and high throughput.

Here is an example /etc/sysctl.conf of our production servers:

```
fs.file-max = 51200

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = hybla
```
Of course, remember to execute sysctl -p to reload the config at runtime.

## clinet 使用

### Android

下载地址：[v5.3.3](https://github.com/shadowsocks/shadowsocks-android/releases/download/v5.3.3/shadowsocks-universal-5.3.3.apk)

#### 配置内容
新增配置文件，填写以下内容：
- 服务器：公网IP或域名
- 远程端口： server 放行的 tcp 端口
- 加密方式：同于 server 配置
- 路由： 绕过局域网及大陆地址

 关于设置选项中的高级配置，并未做修改

### win

下载地址：[v4.4.1.0](https://github.com/shadowsocks/shadowsocks-windows/releases/download/4.4.1.0/Shadowsocks-4.4.1.0.zip)

#### 配置内容

关联 ss:// 链接 \
系统代理--全局模式 \
服务器--配置文件，填写以下内容：

- 服务器：公网IP或域名
- 远程端口： server 放行的 tcp 端口
- 加密方式：同于 server 配置