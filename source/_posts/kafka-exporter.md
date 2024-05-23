---
title: kafka-exporter
author: LC
toc: true
date: 2024-04-30 23:20:00
img:
top:
cover:
password:
summary: kafka 指标导出
categories: Opentelemetry
tags: [metrics]
---

并没有找到官方比较权威的指标获取工具，来自社区的应用各有所长，使用以下工具，各取其长
## 1. kafka_exporter
下载并执行，获取指标太少，弃用
   
```
nohup kafka_exporter --kafka.server=10.8.0.88:9092 &
```

## 2. [jmx_exporter]( https://github.com/prometheus/jmx_exporter )
### 下载 java-agent, 需要在每个节点配置
```
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
```
### 运行方式
#### Running the Standalone HTTP Server（未使用）
#### Running the Java Agent（推荐使用）
在 `kafka-server-start.sh` 头部增加代码声明，agent将和服务共同启动
```
export KAFKA_JMX_OPTS="-javaagent:/usr/local/kafka/bin/jmx_prometheus_javaagent-0.20.0.jar=9990:/usr/local/kafka/config/kafka-jmx.yml"
```

各节点 kafka 已经由 systemd 管理，此处执行 systemctl restart kafka 即可
#### [此处是官方的jmx_exporter使用的 javaagents 配置文件模板](https://github.com/prometheus/jmx_exporter/blob/main/example_configs/kafka-kraft-3_0_0.yml) kafka-jmx.yml
```yaml
lowercaseOutputName: true

rules:
# Special cases and very specific rules
- pattern : kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
  name: kafka_server_$1_$2
  type: GAUGE
  labels:
    clientId: "$3"
    topic: "$4"
    partition: "$5"
- pattern : kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
  name: kafka_server_$1_$2
  type: GAUGE
  labels:
    clientId: "$3"
    broker: "$4:$5"
- pattern : kafka.coordinator.(\w+)<type=(.+), name=(.+)><>Value
  name: kafka_coordinator_$1_$2_$3
  type: GAUGE
# Kraft current state info metric rule
- pattern: "kafka.server<type=raft-metrics><>current-state: ([a-z]+)"
  name: kafka_server_raft_metrics_current_state_info
  type: GAUGE
  value: 1
  labels:
    "state": "$1"
# Kraft specific rules for raft-metrics, raft-channel-metrics, broker-metadata-metrics
- pattern: kafka.server<type=(.+)><>([a-z-]+)-total
  name: kafka_server_$1_$2_total
  type: COUNTER
- pattern: kafka.server<type=(.+)><>([a-z-]+)
  name: kafka_server_$1_$2
  type: GAUGE

# Generic per-second counters with 0-2 key/value pairs
- pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+), (.+)=(.+)><>Count
  name: kafka_$1_$2_$3_total
  type: COUNTER
  labels:
    "$4": "$5"
    "$6": "$7"
- pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+)><>Count
  name: kafka_$1_$2_$3_total
  type: COUNTER
  labels:
    "$4": "$5"
- pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*><>Count
  name: kafka_$1_$2_$3_total
  type: COUNTER

# Quota specific rules
- pattern: kafka.server<type=(.+), user=(.+), client-id=(.+)><>([a-z-]+)
  name: kafka_server_quota_$4
  type: GAUGE
  labels:
    resource: "$1"
    user: "$2"
    clientId: "$3"
- pattern: kafka.server<type=(.+), client-id=(.+)><>([a-z-]+)
  name: kafka_server_quota_$3
  type: GAUGE
  labels:
    resource: "$1"
    clientId: "$2"
- pattern: kafka.server<type=(.+), user=(.+)><>([a-z-]+)
  name: kafka_server_quota_$3
  type: GAUGE
  labels:
    resource: "$1"
    user: "$2"

# Generic gauges with 0-2 key/value pairs
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Value
  name: kafka_$1_$2_$3
  type: GAUGE
  labels:
    "$4": "$5"
    "$6": "$7"
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Value
  name: kafka_$1_$2_$3
  type: GAUGE
  labels:
    "$4": "$5"
- pattern: kafka.(\w+)<type=(.+), name=(.+)><>Value
  name: kafka_$1_$2_$3
  type: GAUGE

# Emulate Prometheus 'Summary' metrics for the exported 'Histogram's.
#
# Note that these are missing the '_sum' metric!
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Count
  name: kafka_$1_$2_$3_count
  type: COUNTER
  labels:
    "$4": "$5"
    "$6": "$7"
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*), (.+)=(.+)><>(\d+)thPercentile
  name: kafka_$1_$2_$3
  type: GAUGE
  labels:
    "$4": "$5"
    "$6": "$7"
    quantile: "0.$8"
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Count
  name: kafka_$1_$2_$3_count
  type: COUNTER
  labels:
    "$4": "$5"
- pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*)><>(\d+)thPercentile
  name: kafka_$1_$2_$3
  type: GAUGE
  labels:
    "$4": "$5"
    quantile: "0.$6"
- pattern: kafka.(\w+)<type=(.+), name=(.+)><>Count
  name: kafka_$1_$2_$3_count
  type: COUNTER
- pattern: kafka.(\w+)<type=(.+), name=(.+)><>(\d+)thPercentile
  name: kafka_$1_$2_$3
  type: GAUGE
  labels:
    quantile: "0.$4"

# Generic gauges for MeanRate Percent
# Ex) kafka.server<type=KafkaRequestHandlerPool, name=RequestHandlerAvgIdlePercent><>MeanRate
- pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>MeanRate
  name: kafka_$1_$2_$3_percent
  type: GAUGE
- pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>Value
  name: kafka_$1_$2_$3_percent
  type: GAUGE
- pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*, (.+)=(.+)><>Value
  name: kafka_$1_$2_$3_percent
  type: GAUGE
  labels:
    "$4": "$5"
```

#### prometheus.yml
```
- job_name: "kafka_jmx"
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.249.1:9990','192.168.249.2:9990','192.168.249.3:9990']
```

## 3. Kiminon 使用
#### 可以二进制、docker、 helm 部署 kiminon; 可以监控多源; 运行后访问 IP:port/metrics

Cluster Dashboard: [https://grafana.com/grafana/dashboards/14012](https://grafana.com/grafana/dashboards/14012)
Consumer Group Dashboard: [https://grafana.com/grafana/dashboards/14014](https://grafana.com/grafana/dashboards/14014)
Topic Dashboard: [https://grafana.com/grafana/dashboards/14013](https://grafana.com/grafana/dashboards/14013)

### 3.1 二进制使用
#### 命令行试运行
```bash
wget https://github.com/redpanda-data/kminion/releases/download/v2.2.6/kminion_2.2.6_linux_amd64.tar.gz
tar xvf kminion_2.2.6_linux_amd64.tar.gz kminion
sudo mv kminion /usr/local/bin
# 编写配置文件，并以环境变量的方式什么其路径
export CONFIG_FILEPATH=~/.kminion.yml
kminon # 命令行运行
```
#### systemd 托管
/etc/systemd/system/kminion.service
```
[Unit]
Description=kminion
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kminion
Restart=on-failure
Environment="CONFIG_FILEPATH=/home/keyword/.kminion.yml"

[Install]
WantedBy=multi-user.target
```
#### 配置文件 `/home/keyword/.kminion.yml`
```yaml
logger:
  # Valid values are: debug, info, warn, error, fatal, panic
  level: info

kafka:
  brokers: ["10.8.0.88:9092","10.8.0.89:9092","10.8.0.90:9092"]
  clientId: "kminion"
  rackId: ""
  tls:
    enabled: false
    caFilepath: ""
    certFilepath: ""
    keyFilepath: ""
    # base64 encoded tls CA, cannot be set if 'caFilepath' is set
    ca: ""
    # base64 encoded tls cert, cannot be set if 'certFilepath' is set
    cert: ""
    # base64 encoded tls key, cannot be set if 'keyFilepath' is set
    key: ""
    passphrase: ""
    insecureSkipTlsVerify: false

minion:
  consumerGroups:
    # Enabled specifies whether consumer groups shall be scraped and exported or not.
    enabled: true
    # Mode specifies whether we export consumer group offsets using the Admin API or by consuming the internal
    # __consumer_offsets topic. Both modes have their advantages and disadvantages.
    # * adminApi:
    #     - Useful for managed kafka clusters that do not provide access to the offsets topic.
    # * offsetsTopic
    #     - Enables kminion_kafka_consumer_group_offset_commits_total metrics.
    #     - Processing the offsetsTopic requires slightly more memory and cpu than using the adminApi. The amount depends on the
    #       size and throughput of the offsets topic.
    scrapeMode: adminApi # Valid values: adminApi, offsetsTopic
    # Granularity can be per topic or per partition. If you want to reduce the number of exported metric series and
    # you aren't interested in per partition lags you could choose "topic" where all partition lags will be summed
    # and only topic lags will be exported.
    granularity: partition
    # AllowedGroups are regex strings of group ids that shall be exported
    # You can specify allowed groups by providing literals like "my-consumergroup-name" or by providing regex expressions
    # like "/internal-.*/".
    allowedGroups: [ ".*" ]
    # IgnoredGroups are regex strings of group ids that shall be ignored/skipped when exporting metrics. Ignored groups
    # take precedence over allowed groups.
    ignoredGroups: [ ]
  topics:
    # Granularity can be per topic or per partition. If you want to reduce the number of exported metric series and
    # you aren't interested in per partition metrics you could choose "topic".
    granularity: partition
    # AllowedTopics are regex strings of topic names whose topic metrics that shall be exported.
    # You can specify allowed topics by providing literals like "my-topic-name" or by providing regex expressions
    # like "/internal-.*/".
    allowedTopics: [ ".*" ]
    # IgnoredTopics are regex strings of topic names that shall be ignored/skipped when exporting metrics. Ignored topics
    # take precedence over allowed topics.
    ignoredTopics: [ ]
    # infoMetric is a configuration object for the kminion_kafka_topic_info metric
    infoMetric:
      # ConfigKeys are set of strings of Topic configs that you want to have exported as part of the metric
      configKeys: [ "cleanup.policy" ]
  logDirs:
    # Enabled specifies whether log dirs shall be scraped and exported or not. This should be disabled for clusters prior
    # to version 1.0.0 as describing log dirs was not supported back then.
    enabled: true

  # EndToEnd Metrics
  # When enabled, kminion creates a topic which it produces to and consumes from, to measure various advanced metrics. See docs for more info
  endToEnd:
    enabled: true
      #enabled: false
    # How often to send end-to-end test messages
    probeInterval: 100ms
    topicManagement:
      # You can disable topic management, without disabling the testing feature.
      # Only makes sense if you have multiple kminion instances, and for some reason only want one of them to create/configure the topic
      enabled: true

      # Name of the topic kminion uses to send its test messages
      # You do *not* need to change this if you are running multiple kminion instances on the same cluster.
      # Different instances are perfectly fine with sharing the same topic!
      name: kminion-end-to-end

      # How often kminion checks its topic to validate configuration, partition count, and partition assignments
      reconciliationInterval: 10m

      # Depending on the desired monitoring (e.g. you want to alert on broker failure vs. cluster that is not writable)
      # you may choose replication factor 1 or 3 most commonly.
      replicationFactor: 1

      # Rarely makes sense to change this, but maybe if you want some sort of cheap load test?
      # By default (1) every broker gets one partition
      partitionsPerBroker: 1

    producer:
      # This defines:
      # - Maximum time to wait for an ack response after producing a message
      # - Upper bound for histogram buckets in "produce_latency_seconds"
      ackSla: 5s
      # Can be to "all" (default) so kafka only reports an end-to-end test message as acknowledged if
      # the message was written to all in-sync replicas of the partition.
      # Or can be set to "leader" to only require to have written the message to its log.
      requiredAcks: all

    consumer:
      # Prefix kminion uses when creating its consumer groups. Current kminion instance id will be appended automatically
      groupIdPrefix: kminion-end-to-end

      # Whether KMinion should try to delete empty consumer groups with the same prefix. This can be used if you want
      # KMinion to cleanup it's old consumer groups. It should only be used if you use a unique prefix for KMinion.
      deleteStaleConsumerGroups: false

      # This defines:
      # - Upper bound for histogram buckets in "roundtrip_latency"
      # - Time limit beyond which a message is considered "lost" (failed the roundtrip)
      roundtripSla: 20s

      # - Upper bound for histogram buckets in "commit_latency_seconds"
      # - Maximum time an offset commit is allowed to take before considering it failed
      commitSla: 10s

exporter:
  host: "10.8.0.88"
  port: 9095
```

#### prometheus.yml
```
- job_name: "kafka_kminion"
    metrics_path: /metrics
    static_configs:
      - targets: ['10.8.0.88:9095']
```

### 3.2 使用 docker-compose
#### docker-compose.yml
```yaml TI:"docker-compose.yml"
version: '3'

services:
  kminion:
    image: vectorized/kminion:latest
    container_name: kafka-minion
    ports:
      - 9095:8080
    restart: unless-stopped
    environment:
      CONFIG_FILEPATH: /etc/kminion.yml
    volumes:
      - ./kminion.yml:/etc/kminion.yml
```

#### `kminion.yml` 配置文件使用内容如下
```yaml
logger:
  # Valid values are: debug, info, warn, error, fatal, panic
  level: info

kafka:
  brokers: ["10.8.0.88:9092","10.8.0.89:9092","10.8.0.90:9092"]
  clientId: "kminion"
  rackId: ""
  tls:
    enabled: false
    caFilepath: ""
    certFilepath: ""
    keyFilepath: ""
    # base64 encoded tls CA, cannot be set if 'caFilepath' is set
    ca: ""
    # base64 encoded tls cert, cannot be set if 'certFilepath' is set
    cert: ""
    # base64 encoded tls key, cannot be set if 'keyFilepath' is set
    key: ""
    passphrase: ""
    insecureSkipTlsVerify: false

  sasl:
    # Whether or not SASL authentication will be used for authentication
    enabled: false
    # Username to use for PLAIN or SCRAM mechanism
    username: ""
    # Password to use for PLAIN or SCRAM mechanism
    password: ""
    # Mechanism to use for SASL Authentication. Valid values are PLAIN, SCRAM-SHA-256, SCRAM-SHA-512, GSSAPI, OAUTHBEARER
    mechanism: "PLAIN"
    # GSSAPI / Kerberos config properties
    gssapi:
      authType: ""
      keyTabPath: ""
      kerberosConfigPath: ""
      serviceName: ""
      username: ""
      password: ""
      realm: ""
      enableFast: true
    # OAUTHBEARER config properties
    oauth:
      tokenEndpoint: ""
      clientId: ""
      clientSecret: ""
      scope: ""

minion:
  consumerGroups:
    # Enabled specifies whether consumer groups shall be scraped and exported or not.
    enabled: true
    # Mode specifies whether we export consumer group offsets using the Admin API or by consuming the internal
    # __consumer_offsets topic. Both modes have their advantages and disadvantages.
    # * adminApi:
    #     - Useful for managed kafka clusters that do not provide access to the offsets topic.
    # * offsetsTopic
    #     - Enables kminion_kafka_consumer_group_offset_commits_total metrics.
    #     - Processing the offsetsTopic requires slightly more memory and cpu than using the adminApi. The amount depends on the
    #       size and throughput of the offsets topic.
    scrapeMode: adminApi # Valid values: adminApi, offsetsTopic
    # Granularity can be per topic or per partition. If you want to reduce the number of exported metric series and
    # you aren't interested in per partition lags you could choose "topic" where all partition lags will be summed
    # and only topic lags will be exported.
    granularity: partition
    # AllowedGroups are regex strings of group ids that shall be exported
    # You can specify allowed groups by providing literals like "my-consumergroup-name" or by providing regex expressions
    # like "/internal-.*/".
    allowedGroups: [ ".*" ]
    # IgnoredGroups are regex strings of group ids that shall be ignored/skipped when exporting metrics. Ignored groups
    # take precedence over allowed groups.
    ignoredGroups: [ ]
  topics:
    # Granularity can be per topic or per partition. If you want to reduce the number of exported metric series and
    # you aren't interested in per partition metrics you could choose "topic".
    granularity: partition
    # AllowedTopics are regex strings of topic names whose topic metrics that shall be exported.
    # You can specify allowed topics by providing literals like "my-topic-name" or by providing regex expressions
    # like "/internal-.*/".
    allowedTopics: [ ".*" ]
    # IgnoredTopics are regex strings of topic names that shall be ignored/skipped when exporting metrics. Ignored topics
    # take precedence over allowed topics.
    ignoredTopics: [ ]
    # infoMetric is a configuration object for the kminion_kafka_topic_info metric
    infoMetric:
      # ConfigKeys are set of strings of Topic configs that you want to have exported as part of the metric
      configKeys: [ "cleanup.policy" ]
  logDirs:
    # Enabled specifies whether log dirs shall be scraped and exported or not. This should be disabled for clusters prior
    # to version 1.0.0 as describing log dirs was not supported back then.
    enabled: true

  # EndToEnd Metrics
  # When enabled, kminion creates a topic which it produces to and consumes from, to measure various advanced metrics. See docs for more info
  endToEnd:
    enabled: true
      #enabled: false
    # How often to send end-to-end test messages
    probeInterval: 100ms
    topicManagement:
      # You can disable topic management, without disabling the testing feature.
      # Only makes sense if you have multiple kminion instances, and for some reason only want one of them to create/configure the topic
      enabled: true

      # Name of the topic kminion uses to send its test messages
      # You do *not* need to change this if you are running multiple kminion instances on the same cluster.
      # Different instances are perfectly fine with sharing the same topic!
      name: kminion-end-to-end

      # How often kminion checks its topic to validate configuration, partition count, and partition assignments
      reconciliationInterval: 10m

      # Depending on the desired monitoring (e.g. you want to alert on broker failure vs. cluster that is not writable)
      # you may choose replication factor 1 or 3 most commonly.
      replicationFactor: 1

      # Rarely makes sense to change this, but maybe if you want some sort of cheap load test?
      # By default (1) every broker gets one partition
      partitionsPerBroker: 1

    producer:
      # This defines:
      # - Maximum time to wait for an ack response after producing a message
      # - Upper bound for histogram buckets in "produce_latency_seconds"
      ackSla: 5s
      # Can be to "all" (default) so kafka only reports an end-to-end test message as acknowledged if
      # the message was written to all in-sync replicas of the partition.
      # Or can be set to "leader" to only require to have written the message to its log.
      requiredAcks: all

    consumer:
      # Prefix kminion uses when creating its consumer groups. Current kminion instance id will be appended automatically
      groupIdPrefix: kminion-end-to-end

      # Whether KMinion should try to delete empty consumer groups with the same prefix. This can be used if you want
      # KMinion to cleanup it's old consumer groups. It should only be used if you use a unique prefix for KMinion.
      deleteStaleConsumerGroups: false

      # This defines:
      # - Upper bound for histogram buckets in "roundtrip_latency"
      # - Time limit beyond which a message is considered "lost" (failed the roundtrip)
      roundtripSla: 20s

      # - Upper bound for histogram buckets in "commit_latency_seconds"
      # - Maximum time an offset commit is allowed to take before considering it failed
      commitSla: 10s
```