---
title: mysqld-exporter
author: LC
toc: true
date: 2024-04-30 23:20:00
img:
top:
cover:
password:
summary: mysql prometheus 指标导出
categories: OpenTelemetry
tags: [metrics]
---

## 1.前置条件
 mysql 中准备暴露指标的用户和主机地址( exporter  ip)，并在相应表中必要授权
```bash
CREATE USER 'mysqld_exporter'@'10.1.0.81' IDENTIFIED BY 'keyword@2020';
GRANT REPLICATION CLIENT, PROCESS ON *.* TO 'mysqld_exporter'@'10.1.0.81';
GRANT SELECT ON performance_schema.* TO 'mysqld_exporter'@'10.1.0.81';
FLUSH PRIVILEGES;
```
## 2. 配置 mysqld_exporter 用户
```
tee > .db.cnf << EOF
[client]
user=mysqld_exporter
password=keyword@2020
EOF
```
## 3. 下载
```
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.1/mysqld_exporter-0.15.1.linux-amd64.tar.gz
tar xvf mysqld_exporter-0.15.1.linux-amd64.tar.gz
sudo mv mysqld_exporter-0.15.1.linux-amd64/mysqld_exporter /usr/local/bin/
```
## 4. 使用 systemd 管理
```
sudo tee > /etc/systemd/system/mysqld_exporter.service << EOF
[Unit]
Description=mysql_exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mysqld_exporter --config.my-cnf="/home/keyword/mysql/.db.cnf"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mysqld_exporter
```
## 5. 此时可以去访问默认的 9104/metrics
```
- job_name: 'mysqld_exporter'  
  metrics_path: /metrics  
  static_configs:  
  - targets:
    - 10.1.0.81:9104
```

## 6. 多源监测
- 不用在每个 mysql 去安装 exporter
- 在 .db.cnf 新增另一个数据库的监控专用用户信息; 保证服务端进行上述用户权限配置即可
```ini
[client]
host = 10.1.0.81
port = 3306
user = mysqld_exporter
password = keyword@2020

[client-db2]
host = 10.8.0.90
port = 3306
user = mysqld_exporter
password = keyword@2020
```

>[!bug] 问题 1
>Get " http://10.8.0.90:3306/probe?auth_module=client-db2&target=10.8.0.90%3A3306": dial tcp 10.8.0.90:3306: connect: connection refused

>[!Solution] 解决
> 1. mysql bind-address 未修改，仍然限定的是其本身回环地址，'/etc/mysql/mysql.conf.d/mysqld.cnf'
> 2. mysql 中，创建用户并管理 client 服务器地址需要正确限定， user@client ip / 网段

>[!bug] 问题 2
>Get " http://10.1.0.81:3306/probe?auth_module=client&target=10.1.0.81%3A3306": net/http: HTTP/1.x transport connection broken: malformed HTTP status code "'172.22.0.2'"\
>修改 prometheus.yml 之后正常

调整后的最终版本 prometheus.yml
```Yaml TI："successful version"
  - job_name: 'multiple_mysql'
    static_configs: #也可以将此替换为其他的服务发现配置
      - targets:
          - 10.1.0.81:3306  # mysql 1
        labels:
          modes: Master  # 自己定义的标签
          auth_module: client  # 必须指定，值来源于用户信息的cnf文件中，如果多个数据库使用的用户相同，可以使用同一个auth配置
      - targets:
          - 10.8.0.90:3306  # mysql 2
        labels:
          modes: slave
          auth_module: client-db2
    relabel_configs:
      # 核心是获取 `__parm_target` 就是 上面params抓取的target
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      # 配置后只有此 endpoint，是 exporter 的地址， target 将成为标签
      - target_label: __address__
        replacement: 10.1.0.81:9104
      # 下面将把 auth_module 这个标签的值替换为__param_auth_module的值，__param_auth_module即上方static_configs下的params配置
      - source_labels: [auth_module]
        target_label: __param_auth_module
      # 下面将删除 auth_module 这个标签
      - action: labeldrop
        regex: auth_module
```

## 7. reference
   [技术分享 | mysqld\_exporter 收集多个 MySQL 监控避坑 - 墨天轮](https://www.modb.pro/db/565900)