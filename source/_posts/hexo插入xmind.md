---
title: test
date: 2024-03-08 22:40:44
tags: hexo
---
### 1. 项目来源[此处](https://github.com/maxchang3/hexo-markmap)
### 2. .xmind 文件转换为 md 文件，放入下方 markmap 中
```
{% markmap 400px %}
- links
- **inline** ~~text~~ *styles*
- multiline
  text
- `inline code`
- ```js
  console.log('code block');
  console.log('code block');
  ```
- KaTeX - $x = {-b \pm \sqrt{b^2-4ac} \over 2a}$
{% endmarkmap %}
```
以上代码的显示效果如此
{% markmap 400px %}
- links
- **inline** ~~text~~ *styles*
- multiline
  text
- `inline code`
- ```js
  console.log('code block');
  console.log('code block');
  ```
- KaTeX - $x = {-b \pm \sqrt{b^2-4ac} \over 2a}$
{% endmarkmap %}

### 3. xmind2md
[作者指路](https://github.com/EXKulo/xmind_markdown_converter)
使用此程序：`python xmind2md.py -source {xmind的文件路径} -output {markdown的输出路径}` \
第一次在win电脑准备python环境，解决了py、pip的环境变量之后，`pip install xmind ` 出现这个问题：`python 报错 Missing dependencies for SOCKS support` \
这是我为浏览器设置的代理，$ENV:all_proxy == socks5://127.0.0.1:1234;设置环境变量为空发现也不能解决问题。 \
实际原因是：Python 本身在没有安装 pysocks 时并不支持 socks5 代理 \
pip 不能install ，所以安装了miniconda，然后`conda install pysocks`；之后可以正常使用pip install
### 4. 转换失败
可惜源 xmind 文件来自更高的 xmind 软件，保存后不能使用python 引入的 xmind 包打开文件，所以没能成功转换为 md 文件；而他本身导出需要会员才能进行md保存。

### 5. 破解版 xmind 测试
{% markmap %}
# monitor

业务性能出发
系统稳定出发

## 采集

找一个（全家桶）采集器

### 对象

- 集群

  - 主机(系统\服务\用户登录--登录ip)

    - 物理机

      - GPU

        - a5000 *3

        - a4000 *3

        - p100 *1

      - cpu

        - node

          - minio

            - 730 *3

              - prometheus

                - https://min.io/docs/minio/linux/operations/monitoring/collect-minio-metrics-using-prometheus.html

                  - disk

                    - cluster capacity utilization

                    - node disk utilization

                    - total counts

                    - offline counts

                    - 读写延迟

                    - 吞吐量/s

                  - replication

                    - 指定bucket，至少复制失败一次的字节总数

                    - 指定bucket，待复制字节总数

                    - 已复制的字节总数

                    - 挂起的复制操作总数

                    - 失败的复制操作总数

                  - S3 requests

                    - total

                    - errors

                    - current active

                    - different error summary

                  - W/R

                    - bytes total

                    - rate

                    - 自我修复运行失败对象统计

                - https://blog.csdn.net/weixin_46514651/article/details/129107130#t1

          - mfs

            - 743ac *3

              - exporter

                - https://github.com/uu/moosefs_exporter/releases/tag/v0.1.1

              - cmdli

                - https://grafana.com/grafana/dashboards/16700-moosefs-overview/

          - milvus

            - 743ac *3

              - prometheus

                - https://milvus.io/docs/monitor.md

          - clickhouse

            - 743ac *3

              - prometheus + 自身库中的指标数据

                - https://blog.csdn.net/hongguo880/article/details/129854518

                  - 查询处理速度

                  - 查询被抢占的次数

                  - 副本 send/Receive datas

                  - 连接到分布式表中插入数据的远程服务器的数量

                  - TCP connections

                  - pgsql 协议连接数量

                  - openfiles for R/W

                  - NetworkReceive / NetworkSend

                  - 查询处理线程数

                  - IO预处理活跃线程数

                  - IO写线程池中活跃线程数

                  - 线程池总活跃数量

                  - 磁盘读取操作的耗时

                  - 为合并操作预留的磁盘空间

                - https://github.com/ClickHouse/ClickHouse/blob/master/src/Common/CurrentMetrics.cpp

          - citus

            - 743ac *5

              - 1 coordinate 4 worker
                (1=coordinator + nginx for cluster)

                - https://pigsty.cc/zh/docs/deploy/monitor/

                - https://github.com/prometheus-community/postgres_exporter

          - kuberay

            - 2028hr *12

              - prometheus

                - https://docs.ray.io/en/master/cluster/kubernetes/k8s-ecosystem/prometheus-grafana.html#kuberay-prometheus-grafana

          - monitor（prom+thanos）

            - 743ac *1

              - Prometheus 自身指标

        - vmware

          - inboc

            - 740

          - ibswufe

            - 730

      - 所有主机层级--系统性能

        - node_exporter + process-exporter

          - node-exporter 新增非默认参数开启

            - drm:
              Expose GPU metrics using sysfs / DRM, amdgpu is the only driver which exposes this information through DRM

            - ethtool:
              Exposes network interface information and network driver statistics equivalent to ethtool, ethtool -S, and ethtool -i.

            - logind:
              Exposes session counts from logind

            - mountstats:
              Exposes filesystem statistics from /proc/self/mountstats. Exposes detailed NFS client statistics

            - nfs\nfsd:


					- https://github.com/prometheus/node_exporter
	
		- 虚拟机
	
			- win-server
	
				- github: windows_exporter

collectors needed

					- cpu--default
	
					- service--default
	
					- os--default
	
					- diskdrive collector
	
					- smb
	
					- logon
	
					- tcp
	
				- https://help.aliyun.com/zh/arms/prometheus-monitoring/how-do-i-install-and-configure-windows-exporter
	
				- https://i4t.com/16728.html
	
			- linux-deployed
	
				- inboc
	
					- sys
	
						- LDAP
	
							- exporter
	
								- https://github.com/tomcz/openldap_exporter
	
									- openldap-exporter：查看已经启用的模块
	
									- process-exporter--请求连接数、资源使用
	
									- Subtopic 3
	
						- DNS
	
							- dns_exporter
	
								- https://github.com/prometheus-community/bind_exporter
	
									- uptime
	
									- queries counts
	
										- resolver
	
										- errors
	
									- response counts
	
										- resolver
	
										- errors
	
								- https://grafana.com/grafana/dashboards/1666-bind-dns/
	
						- nginx
	
							- exporter
	
								- https://blog.csdn.net/manba_24/article/details/123007949
	
									- server 连接统计：活跃、等待、R、W、
	
									- server 请求统计，group by type、 host、status code
	
									- 各个upstream 状态、请求总数、Sent/Recieve 字节统计、速率
	
									- 各个upstream 响应统计 ，精确到状态码，平均响应时长
	
									- Server zone：request 统计、响应统计--区分状态码
	
									- server zone：Sent/Recieve 字节统计、速率
	
								- https://github.com/nginxinc/nginx-prometheus-exporter
	
						- chrony-apt
	
							- exporter
	
								- https://github.com/SuperQ/chrony_exporter
	
									- 源地址
	
									- 同步状态
	
									- 延迟或错误
	
						- bastillion-gz
	
						- mysql-apt
	
							- exporter
	
								- https://github.com/prometheus/mysqld_exporter
	
									- up/down
	
									- cpu 、Mem
	
									- 连接数
	
										- MAX
	
										- 已创建的
	
										- 已连接的
	
										- 活跃的
	
										- 超时连接
	
									- openfiles
	
										- limits
	
										- 正在打开
	
										- 已经打开
	
									- 线程数、running status
	
									- 主从延迟
	
									- IO PerSecod
	
									- querys
	
										-  query PerSecond
	
										- 请求获取锁，但需要等待的请求数
	
									- Transcantion Persecond
	
									- received/send bytes
	
									- 查询速率
	
										- 每分钟查询数
	
										- 慢查询数
	
										- 数据页数--洁页、脏页
	
									- table locks 
	
						- postgres
	
							- exporter
	
								- https://github.com/prometheus-community/postgres_exporter
	
									- 总连接数、使用率、30s内新增、活跃和空闲会话
	
									- current data fetched 、inserted 、 updated、deleted
	
									- openfiles
	
									- 事务统计 终止、已提交 、比率
	
									- 锁表 数量
	
									- 死锁数量统计、增长率
	
									- 缓存命中率
	
									- 表自动清理
	
									- 复制槽使用情况
	
									- 死亡元组的占比 变化趋势
	
									- 事务获取锁的利用率趋势
	
									- 索引的空间膨胀率变化情况
	
									- 表的空间膨胀率变化情况
	
						- harbor--docker
	
							- posted itself 
	
								- https://goharbor.io/docs/2.2.0/administration/metrics/
	
								- https://blog.51cto.com/lidabai/5177735
	
						- nexus-docker
	
							- posted itself 
	
								- https://zhuanlan.zhihu.com/p/551036838
	
						- samba
	
							- windows-exporter
	
								- smb-collector in windows-exporter
	
									- user connections
	
									- openfiles
	
									- disk
	
										- IO times PerSecend
	
										- IO duration PerTime
	
										- capacity
	
										- utilization of each partition
	
										- usage predict
	
						- rke2 *3
	
							- 同于其他k8s集群节点
	
								- rancher 默认部署了node-exporter & kube-state-metrics
	
							- rancher 监控和告警
	
								- https://docs.rancher.cn/docs/rancher2.5/monitoring-alerting/_index
	
					- dev
	
						- nfs
	
							- node_exorter
	
								- user connections、挂载状态
	
								- 传输速率
	
								- disk
	
									- IO times PerSecend
	
									- IO duration PerTime
	
									- capacity
	
									- utilization of each partition
	
									- usage predict
	
						- nginx
	
							- 反向代理/负载均衡citus-backup的worker节点
	
								- https://github.com/vozlt/nginx-module-vts
	
									- server 连接统计：活跃、等待、R、W、
	
									- server 请求统计，group by type、 host、status code
	
									- 各个upstream 状态、请求总数、Sent/Recieve 字节统计、速率
	
									- 各个upstream 响应统计 ，精确到状态码，平均响应时长
	
									- Server zone：request 统计、响应统计--区分状态码
	
									- server zone：Sent/Recieve 字节统计、速率
	
						- mgmt
	
						- kafka cluster *3-apt
	
							- https://github.com/danielqsj/kafka_exporter
	
							- https://github.com/prometheus/jmx_exporter?tab=readme-ov-file
	
							- https://github.com/redpanda-data/kminion
	
							- https://zhuanlan.zhihu.com/p/127954833
	
							- https://blog.csdn.net/x763795151/article/details/119705372
	
							- https://blog.csdn.net/LCBUSHIHAHA/article/details/132216491#t6
	
							- didi 开源knowstream 具有比较完善的kafka集群监控方案，但在我们当前的kafka规模下略显笨重
	
						- redis cluster *6-apt
	
							- exporter
	
								- https://www.cnblogs.com/fsckzy/p/12053604.html
	
									- cpu、mem、input/output bytes
	
									- 客户端连接数、使用率、拒绝的客户端连接
	
									- master/slave 连接数、重连接
	
									- command 每分钟执行与耗时
	
									- 每分钟查询的命中/miss次数、命中率
	
									- 各个 db 的 key 数量、每分钟过期统计
	
									- 已过期，尚未删除的 key 数量
	
									- 备份检测
	
						- citus-backup 1+4
	
						- clickhouse-backup *1
	
						- inboc-dev-ubuntu 远程开发虚拟机
	
						- message queue
	
							- zookeeper-gz
	
								- https://zookeeper.apache.org/doc/r3.8.0/zookeeperMonitor.html
	
									- 请求延迟指标
	
									- 响应时间、请求堆积数量
	
									- znodes 数量
	
									-  watches的数量
	
									- leader's fllower
	
									- 准备/正在同步的fllower 统计
	
									- openfiles
	
									- 收发包统计
	
							- pulsar
	
								- https://pulsar.apache.org/docs/next/deploy-monitoring/
	
							- etcd
	
								- https://www.lixueduan.com/posts/etcd/17-monitor/
	
								- https://etcd.io/docs/v3.5/metrics/
	
				- ibswufe
	
					- sys
	
						- ibswufe-sys-k8s
	
					- ops
	
						- ibswufe-ops-k8s
	
					- external
	
						- nginx(反向代理sys\ops中的应用)
	
		- k8s节点,主机状态
	
			- inboc
	
				- inboc-sys-k8s
	
					- 3M+4W
	
						- vault
	
							- https://developer.hashicorp.com/vault/tutorials/monitoring/monitor-telemetry-grafana-prometheus
	
								- kv_path 請求來源、統計
	
								- engine 請求、統計
	
						- awx
	
							-  /api/v2/metrics
	
								- https://docs.ansible.com/ansible-tower/latest/html/administration/metrics.html
	
								- https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-awx/
	
						- confluence
	
							- https://confluence.atlassian.com/doc/monitor-application-performance-1115674751.html
	
							- https://github.com/AndreyVMarkelov/prom-confluence-exporter/wiki/Prometheus-Exporter-For-Confluence
	
						- jira
	
							- https://confluence.atlassian.com/adminjiraserver/monitor-jira-with-prometheus-and-grafana-1155466715.html
	
							- https://marketplace.atlassian.com/apps/1222502/prometheus-exporter-for-jira?tab=overview&hosting=server
	
						- gtilab
	
							- https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_exporter.html
	
						- nextcloud
	
							- https://github.com/xperimental/nextcloud-exporter
	
						- jumpserver
	
							- curl -X 'GET' 'https://jumpserver.inboc.net/api/v1/prometheus/metrics/' -H 'accept: application/json' -H 'X-CSRFToken: JanryuKHLosYbQvcqAk0BV3aWd2oiz6fiLzdSQYvBuxuJIHdspOPMReRKfSzaIhV'
	
						- rockchart 
	
							- https://github.com/RocketChat/Rocket.Chat.Metrics
	
						- lam
	
						- password
	
				- inboc-ops-k8s
	
					- 3M+3W
	
						- traefik
	
							- https://doc.traefik.io/traefik/observability/metrics/prometheus/
	
							- https://www.jianshu.com/p/472a0367fb4b
	
						- argo-rollouts
	
							- https://argo-rollouts.readthedocs.io/en/stable/features/controller-metrics/
	
						- jaeger
	
							- https://www.jaegertracing.io/docs/1.31/monitoring/
	
						- istiod
	
							- latency
	
							- traffic
	
							- errors
	
							- saturation
	
						- istio-gateway
	
						- kiali
	
				- inboc-dev-k8s
	
					- 3M+7W(virtua)+12(phy)
	
						- argo-cd
	
							- https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/#api-server-metrics
	
						- argo-workflow
	
							- https://argoproj.github.io/argo-workflows/metrics/#introduction
	
							- https://pipekit.io/blog/how-to-integrate-prometheus-with-argo-workflows
	
						- superset
	
						- kafka-ui
	
						- flink
	
							- https://nightlies.apache.org/flink/flink-docs-release-1.18/zh/docs/deployment/metric_reporters/#prometheus
	
							- https://www.cnblogs.com/jhno1/p/15688300.html#autoid-0-1-0
	
			- deepflow作为参考：

10.13.3.110:30838

			- ibswufe
	
				- ibswufe-sys-k8s
	
					- 3M+3W
	
				- ibswufe-ops-k8s
	
					- 3M+3W
	
			- k8s采集
	
				- cadvisor
	
				- kube-state-metrics
	
				- deepflow-agent？？
	
		- vmware 集群状态
	
			- official

- 存储

  - mfs

    - 客户端挂载失败告警 \ 挂载权限 \使用情况 磁盘情况

      - exporter

        - https://github.com/uu/moosefs_exporter/releases/tag/v0.1.1

      - cmdli

        - https://grafana.com/grafana/dashboards/16700-moosefs-overview/

  - nfs

    - 使用情况

      - from node_exorter / nfs_exporter

  - minio

    - 官方指标--> prom + 证书 + 

      - https://min.io/docs/minio/linux/operations/monitoring/collect-minio-metrics-using-prometheus.html

        - disk

          - cluster capacity utilization

          - node disk utilization

          - total counts

          - offline counts

        - replication

          - 指定bucket，至少复制失败一次的字节总数

          - 指定bucket，待复制字节总数

          - 已复制的字节总数

          - 挂起的复制操作总数

          - 失败的复制操作总数

        - S3 requests

          - total

          - errors

          - current active

          - different error summary

        - W/R

          - bytes total

          - rate

        - 自我修复运行失败对象统计

  - dell 集中式存储

    - 管理端

  - longhorn

    - prom

      - https://longhorn.io/docs/1.5.3/monitoring/prometheus-and-grafana-setup/

      - https://zhangzhuo.ltd/articles/2022/05/19/1652929973831.html

  - smaba

    - smb-collector in windows-exporter

      - user connections

      - openfiles

      - disk

        - IO times PerSecend

        - IO duration PerTime

        - capacity

        - utilization of each partition

        - usage predict

- 网络

  - 服务监控端口 流量

    - process-exporter；
      textfile编写脚本 对主机的端口流量监控(上下行)

      - https://blog.csdn.net/ggbrxxzld/article/details/131227433

        - 主要关注端口和服务的正常

        - 客户端/服务端

        - 传输流量

  - 数据包(转发和丢包)

  - 主机网卡带宽

  - host map

    - deepflow作为参考

  - DNS

    - dns_exporter

      - https://dns-exporter.readthedocs.io/en/stable/configuration.html

        - uptime

        - queries counts

          - resolver

          - errors

        - response counts

          - resolver

          - errors

  - 网站站点

    - blackbox-exporter

      - 域名可达

      - 证书是否过期

      - 请求处理时间

- 数据库

  - clickhouse

    - prometheus + 自身库中的数据

      - https://blog.csdn.net/hongguo880/article/details/129854518

        - 查询处理速度

        - 查询被抢占的次数

        - 副本 send/Receive datas

        - 连接到分布式表中插入数据的远程服务器的数量

        - TCP connections

        - pgsql 协议连接数量

        - openfiles for R/W

        - NetworkReceive / NetworkSend

        - 查询处理线程数

        - IO预处理活跃线程数

        - IO写线程池中活跃线程数

        - 线程池总活跃数量

        - 磁盘读取操作的耗时

        - 为合并操作预留的磁盘空间

  - milvus

    - prometheus

      - https://milvus.io/docs/monitor.md

  - postgresql / citus

    - https://pigsty.cc/zh/docs/deploy/monitor/

    - https://github.com/prometheus-community/postgres_exporter

  - redis

    - exporter

      - https://www.cnblogs.com/fsckzy/p/12053604.html

        - cpu、mem、input/output bytes

        - 客户端连接数、使用率、拒绝的客户端连接

        - master/slave 连接数、重连接

        - command 每分钟执行与耗时

        - 每分钟查询的命中/miss次数、命中率

        - 各个 db 的 key 数量、每分钟过期统计

        - 已过期，尚未删除的 key 数量

        - 备份检测

  - mysql

    - exporter

      - https://github.com/prometheus/mysqld_exporter

        - up/down

        - cpu 、Mem

        - 连接数

          - MAX

          - 已创建的

          - 已连接的

          - 活跃的

          - 超时连接

        - openfiles

          - limits

          - 正在打开

          - 已经打开

          - 子主题 4

        - 线程数、running status

        - 主从延迟

        - IO PerSecod

        - querys

          -  query PerSecond

          -  请求获取锁，但需要等待的请求数

        - Transcantion Persecond

        - received/send bytes

        - 查询速率

          - 每分钟查询数

          - 慢查询数

          - 数据页数--洁页、脏页

        - table locks 

## 图形化

### grafana

- 总分的展示方式

  - 总：

    - 原则：一个大盘、链接所有子页面、可以做必要筛选、看到主要指标的性能或故障

  - 分：

    - 基于集群

      - 主机类型

    - 基于对象

      - 存储

      - 网络

      - 数据库

      - GPU

    - 基于项目(开发)

      - 项目-- 数据库和服务--连接  性能--

## 警告

### nightingale

- 告警规则

  - rules

    - alert name

      - host

        - Mem 

          - 周期(a week)内保持过高+80%或过低-20%的范围，告警进行资源量调整，合理利用

          - 在5m内，每分钟的内存压力保持高位时报警，关注资源消费是否属于正常任务调度

          - 检测到瞬时的 OOM 发生 

        - CPU

          - 周期(a week)内 cpu load 保持过高+80%或过低-20%的范围，告警进行资源量调整，合理利用

          - 10m， cpu load 保持过高+80% 通知检查是否正常资源调度消费

          - 物理机周期(a week)内保持 steal mode > 10% ，虚拟机实例受到了较大程度的资源竞争，本机调整虚拟机创建情况

          - 在5m内，CPU iowait > 10%；磁盘、网络、进程优化

          - 瞬时上下文切换 > 10000/cpu/s

        - Network

          - 5m内，每分钟保持上下行速率>？？MB/s，告警

          - 2m内，收发的错误的packets的比例 > 1%

          - 连接数量/允许连接数,超过阈值80%

        - Disk

          - 5m内，每分钟保持读写速率>？？MB/s，告警

          - free space < 20% left，通知扩容

          - 聚合预测24h磁盘将要满容，警告

          - Disk IO > 0.5, 警告磁盘负载过高

        - FileSystem

          - Host inodes 可用率低于10%，警告

          - 存在文件系统设备错误，警告

      - service

        - Minio

          - disks

            - 5m内，每分钟的读写延迟> 100ms

            - free space < 20% ，通知扩容

            - 当存在离线的disk即警告

          - request 

            - 10 error/s 

          - 生命周期管理

        - nginx

          - 4xx/5xx error 错误率 > 5%

          - 响应延迟高于 2s

          - service down

        - mysqld

          - 出现 restart/down，警告

          - 慢查询增长率>0

          - 从服务器复制滞后 > 30s

          - 线程状态 运行过高、slave thread stopped

          - 连接数/MAX  >  80

          - 文件打开数量超过80%

          - InnoDB 日志等待 > 10/s

        - postgresql

          - 长期没回收已删除的空间

          - 连接使用率超过80%

          - 死锁增长率 > 0

          - 终止/已提交事务 比率 > 2%

          - 消费事务标识符，事件完成率过低 < 5次/min

          - 死锁增长速率 > 1 次/min 

          - 存在未使用的复制槽

          - 死亡元组的占比 .> 10%

          - 事务获取锁的利用率 > 20%

          - 索引的空间膨胀率 > 80%

          - 表的空间膨胀率 > 80%

        - redis

          - instance down

          - master down

          - 集群重连接

          - 有 slaves 未连接

          - 存在未备份

          - 有副本损坏

          - 内存资源紧张

          - 存在连接数使用率>50%、不足5、存在拒绝

        - kafka

          - 活跃的控制器数量

          - 判断是否会脑裂

          - 节点健康状态

          - 离线分区数量大于0

          - 未保持同步的分区数大于0

          - 子主题 6

          - https://i4t.com/13732.html

        - zookeeper

          - service down

          - no leader

          - 发生选举

          - too many leaders

          - alive connections > 60

          - jvm 内存占满

          - znode 创建的watch数量 > 10000

        - longhorn

          - 5m，存储容量趋势保持超过阈值（卷、disk、node三层）

          - 持续2m，存储卷出现错误

          - 存储卷保持5m的警告状态

          - node down

          - 2h，cpu、mem历史使用趋势保持在80%以上

    - labels

      -  severity

         - critical

         - warning

         - info

      -  layer

         - host

         - service

         - container

      -  Subtopic 3

  - 事件管理原则

    - 告警分组

      - 根据以上的lebels设计？

    - 告警抑制

      - ？

    - 告警静默

- 告警分级

  - 层级

    - critical

    - warning

    - info

  - 路由触达媒介

    - 语音--warning+

    - ding talk--ALL

- 自愈管理

  - 预设(状态判断\定位故障\预设执行方式)

    - ？？？

  - 实践增加


{% endmarkmap %}