---
title: bind-exporter
author: LC
toc: true
date: 2024-04-30 23:20:00
img:
top:
cover:
password:
summary: bind9 DNS 指标导出
categories: OpenTelemetry
tags: [metrics]
---

## 1. 安装
bind9 服务器本机，下载二进制包，并移动到 `/usr/local/bin`
```bash
curl -s https://api.github.com/repos/prometheus-community/bind_exporter/releases/latest | grep browser_download_url | grep linux-amd64 |  cut -d '"' -f 4 | wget -qi -
tar xvf bind_exporter*.tar.gz
sudo mv bind_exporter-*/bind_exporter /usr/local/bin
```
bind9 开启指标暴露接口
```bash
sudo tee -a /etc/bind/named.conf.options<<EOF
statistics-channels {
  inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
EOF
```

## 2. Systemd 服务单元文件
需要是运行在 dns local
```bash
sudo tee /etc/systemd/system/bind_exporter.service<<EOF
[Unit]
Description=Prometheus
Documentation=https://github.com/digitalocean/bind_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/bind_exporter \
  --bind.pid-file=/run/named/named.pid \
  --bind.timeout=20s \
  --web.listen-address=0.0.0.0:9153 \
  --web.telemetry-path=/metrics \
  --bind.stats-url=http://127.0.0.1:8053/ \
  --bind.stats-groups=server,view,tasks

Restart=always

[Install]
WantedBy=multi-user.target
EOF
```
## 3. service up
```bash
sudo systemctl daemon-reload
sudo systemctl restart bind_exporter.service
sudo systemctl enable --now bind_exporter
```
## 4. 问题
指标数量少于官方指标，排查发现：url 指定错误的原因

## 5. prometheus.yml
需要对主从分别进行配置
```
  - job_name: 'DNS'
    static_configs:
      - targets: ['10.1.0.81:9153']
        labels:
          alias: dns-master
      - targets: ['10.1.0.82:9153']
        labels:
          alias: dns-slave
```
