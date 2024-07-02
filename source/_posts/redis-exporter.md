---
title: redis-exporter
author: LC
toc: true
date: 2024-04-30 23:20:00
img:
top:
cover:
password:
summary: redis 集群 prometheus 指标导出
categories: OpenTelemetry
tags: [metrics]
---

## 1. 下载并解压二进制文件
#### 在一个节点启用本工具即可
```bash
wget https://github.com/oliver006/redis_exporter/releases/download/v1.58.0/redis_exporter-v1.58.0.linux-amd64.tar.gz
tar -xvf redis_exporter-v1.58.0.linux-amd64.tar.gz 
sudo mv redis_exporter-v1.58.0.linux-amd64/redis_exporter  /usr/local/bin/

sudo tee -a /etc/systemd/system/redis_exporter.service << EOF
[Unit]
Description=Redis Exporter
After=network.target

[Service]
type=forking
ExecStart=redis_exporter -redis.addr 10.8.0.88:6379 -redis.password keyword@2020 -web.listen-address 10.8.0.88:9121  # -redis.password 应该是配置中的 requirepass 的值
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now redis_exporter.service
```

## 2. 查看指标
`curl 10.8.0.88:9121/metrics`

## 3. Prometheus
```yaml
  - job_name: 'redis_exporter_targets'
    static_configs:
      - targets:
        - redis://10.8.0.88:6379
        - redis://10.8.0.88:6380
        - redis://10.8.0.89:6379
        - redis://10.8.0.89:6380
        - redis://10.8.0.90:6379
        - redis://10.8.0.90:6380
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 10.8.0.88:9121 #需要保留，此处为 exporter 地址
```