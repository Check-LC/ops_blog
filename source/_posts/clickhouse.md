---
title: clickhouse
author: LC
toc: true
date: 2024-04-30 23:20:00
img:
top:
cover:
password:
summary: clickhouse 集群简单尝试
categories: Database
tags: [clickhouse]
---

(未曾指定数据目录，仍在原有的系统路径)
(metrika.xml  是否可以选择配置主机变量)

## 一、 安装JDK----zookeeper集群需要
-------

#### 1.  集群需要的机器安装java环境
----------------------------

```
sudo apt-get install -y openjdk-8-jdk
vim /etc/profile                                          # 环境变量，此为系统全局配置，本项目还应对zookeeper进行声明；注意声明时分割，加上:$变量名，避免覆盖
    export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64    [[是]] Java 编程语言 JDK 的顶级目录，软件安装的本地路径，便于定义$path 
    export PATH=PATH=$JAVA_HOME/bin:$PATH                 [[PATH]] 用于指定可执行的二进制文件的位置，此变量不为空，每次声明应加上:$path，避免覆盖
    export CLASSPATH=                                     # 指运行程序所需要的 class 文件的位置,有参考贴说其实非必需，本实验未定义
source /etc/profile
java -version 或 javac -version 检查
```
#### 2.  搭建zookeeper集群
- 元数据管理、集群配置和协调 
------------------------------------
```
tee >> /etc/hosts << EOF
10.13.3.107 server1
10.13.3.106 server2
10.13.3.105 server3
EOF

mkdir /usr/local/zookeeper
cd /opt && wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz
mkdir -p /usr/local/zookeeper/{datadir,logdir}
tar -zxvf /opt/apache-zookeeper-3.8.3-bin.tar.gz -C /usr/local/zookeeper --strip-components=1
echo 1 > /usr/local/zookeeper/datadir/myid
vim zookeeper/conf/zoo.cfg
```
**zoo.cfg 内容如下**
```
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/usr/local/zookeeper/datadir     # 此处两个目录需要创建，并指定自身实际路径
dataLogDir=/usr/local/zookeeper/logdir  
clientPort=2181
server.1=server1:2288:3388                         [[集群信息]],host:心跳端口:数据端口（此处写主机名需要在/etc/hosts做自解析）
server.2=server2:2288:3388                         [[server]].1--唯一标识符，1需要写入存放数据的data/myid 文件中(可以是任意数字，只要二者一致)
server.3=server3:2288:3388                         [[服务器]] Follower 与集群中的 Leader 交换信息的端口:万一集群中的 Leader 服务器挂了，需要一个端口来重新进行选举，用来执行选举时服务器相互通信的端口

-----------以下为j2模板文件写法
{% for host in groups['inboc_dev_clickhouse_group']%}
server.{{ loop.index }}={{hostvars[host].ansible_host}}:2288:3388
{% endfor %}
```
>三台机器都相同配置，需***自解析***，但是注意分别 echo 2/3 > datadir/myid
>pwd
  /usr/local/zookeeper
```
rsync -avz  zookeeper  root@10.13.3.107:/usr/local/zookeeper/zookeeper
rsync -avz  /etc/hosts  root@10.13.3.107:/etc/
source /etc/hosts
```
**systemd 管理**
```
tee /etc/systemd/system/zookeeper.service << EOF
[Unit]  
Description=Apache ZooKeeper distributed coordination server  
After=network.target  
  
[Service]  
Type=forking  
ExecStart=/usr/local/zookeeper/bin/zkServer.sh start  
ExecStop=/usr/local/zookeeper/bin/zkServer.sh stop  
Restart=on-abnormal  
  
[Install]  
WantedBy=multi-user.target
EOF

systemctl daemon-reload
```
**启服务,查看状态**
```
systemctl enable --now zookeeper
systemctl status zookeeper
```   


## 二、 单节点安装，集群内各节点机器均需要安装clickhouse
---------------------

```
sudo apt-get install apt-transport-https ca-certificates dirmngr
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee \
    /etc/apt/sources.list.d/clickhouse.list
sudo apt-get update

sudo apt-get install -y clickhouse-server clickhouse-client

sudo service clickhouse-server start    [[此句是启动clickhouse的服务]]
clickhouse-client # or "clickhouse-client --password"  # 启动客户端
```

## 三、 clickhouse配置集群
------------------------

**vim config.xml**
```
<listen_host>0.0.0.0</listen_host>
<remote_servers></remote_servers>                                 [[此标签内的local, test集群可以注释，不用留下，注释内不能包含注释]]<!--  -->  ( ansible 中 j2 模板会删除这些行的内容)
<include_from>/etc/clickhouse-server/metrika.xml</include_from>   [[此句配置在metrika]].xml段落描述之后，文件为集群配置，但是打了引入标签仍然未识别成功metrika.xml文件路径，将其移动到config.d目录下，成功建立集群
```

vim metrika.xml
```
<yandex>                       <!--此为3分片2副本-->
    <remote_servers>           <!--集群标签-->
        <ck_cluster>           <!--集群名称-->
            <shard>            <!--分片标签-->
                <internal_replication>true</internal_replication>   <!--集群内复制功能-->
                <replica>                                           <!--副本标签，副本指所有文件数量-->      
                    <host>10.13.3.107</host>                        <!--存储本分片的第一个副本的机器-->
                    <port>9000</port>
                </replica>
                <replica>
                    <host>10.13.3.108</host>                        <!--存储本分片的第二个副本的机器-->
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.13.3.108</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>10.13.3.109</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>10.13.3.109</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>10.13.3.107</host>
                    <port>9000</port>
                </replica>
            </shard>
        </ck_cluster>
    </remote_servers>
    <zookeeper>                                    <!--连接zookeeper集群的配置-->
        <node index="1">                           <!--zookeeper集群内的主机唯一标识符-->
            <host>server1</host>                   <!--主机名/IP-->
            <port>2181</port>
        </node>
        <node  index="2">
            <host>server2</host>
            <port>2181</port>
        </node>
        <node index="3">
            <host>server3</host>
            <port>2181</port>
        </node>
    </zookeeper>
    <!--macros>                                   <!--定义宏，在 SQL 查询中使用，以便动态地引用集群中的不同分片和副本--><!--创建集群时非必须-->
        <shard>03</shard>                         <!--第3分片-->（可以视为一个index）
        <replica>03_1</replica>                   <!--第3分片第1副本-->（可以视为一个主机唯一连接，比如IP、hostname）
    </macros>
    <macros>                                      <!--sql使用举例：SELECT COUNT(*) FROM my_table WHERE _shard = '03' AND _replica = '03_1'-->
        <shard>02</shard>                         <!--该标签写法和用法有待斟酌-->
        <replica>02_2</replica>
    </macros-->
    <networks>                                    <!--配置选项允许 Yandex.Metrica 监听来自任何 IPv4 地址的请求-->       
        <ip>0.0.0.0</ip>
    </networks>

    <compression>                                 <!--指定数据在写入到磁盘之前或从磁盘读取之后的压缩方式-->
        <case>
            <min_part_size>10000000000</min_part_size>
            <min_part_size_ratio>0.01</min_part_size_ratio>
            <method>lz4</method>
        </case>
    </compression>
</yandex>

```

	根据以上配置文件，这个 ClickHouse 集群中的每个分片都有两个副本，在这个配置中并没有显式地设置 `parallel_replicas` 参数。因此，如果没有进行额外的配置，这个集群默认情况下在进行分布式查询时，每个分片的两个副本都可以参与查询处理，但是并行副本数量可能会受到其他因素的限制，如数据分片、查询复杂度等。 
	如果需要进一步控制并行副本数量，可以在查询中使用 `SETTINGS max_parallel_replicas` 参数或者在配置文件中设置 `max_parallel_replicas` 参数，以限制每个查询中使用的最大并行副本数量。

vim users.xml
```
<users>
    <!-- If user name was not specified, 'default' user is used. -->
    <user_name>                                                     <!--用户名-->
        <password></password>                                       <!--明文密码，不推荐-->
        <!-- Or -->
        <password_sha256_hex> </password_sha256_hex>                 <!--放置用shell生成SHA256加密密码-->()

        <access_management> 0|1 </access_management>                  <!--不允许 | 允许sql语句生成账户-->

        <networks incl="networks" replace="replace">
        <networks>                                                  <!--用户来源访问控制-->
             <ip>::/0</ip>
        </networks>
        <profile>profile_name</profile>                             <!--对配置做设置的文件名，其中有单独配置段-->

        <quota>default</quota>                                      <!--对用户资源配额做设置的文件-->

        <databases>                                                 <!--限制ClickHouse中由当前用户进行的 `SELECT` 查询所返回的行，从而实现基本的行级安全性--> 
            <database_name>
                <table_name>
                    <filter>expression</filter>                     <!--可以是[UInt8]编码的任何表达式。 它通常包含比较和逻辑运算符, 当filter返回0时, database_name.table1 的该行结果将不会返回给用户-->
                <table_name>
            </database_name>
        </databases>
    </user_name>
    <!-- Other users settings -->
</users>
```

```
SHA256生成密码，利用随机数生成密码，-c 表示需要生成的长度；

PASSWORD=$(base64 < /dev/urandom | head -c14); echo "$PASSWORD"; echo -n "$PASSWORD" | sha256sum | tr -d '-'
生成的第一行为明文密码，用于自己使用；第二行为 sha256 加密字符串，需要配置到下面标签中：
```

各节点重启，并检查
```
systemctl restart clickhouse-server
clickhouse-client -m
	select * from system.clusters;
	SELECT * FROM system.zookeeper WHERE path = '/'；
```


检查连接：8123、9000端口
```
1. echo 'show databases' | curl -H 'X-ClickHouse-User: default' -H 'X-ClickHouse-Key: Inboc@2020' 'http://10.13.3.101:8123/' -d @-
2. clickhouse-client 登录 使用local:9000,
3. datagrip工具，使用9000端口，用户和密码，可以登录
```

-------------------
使用出现的问题：
Python连接8123端口不成功,users.xml 配置错误，删除后可以使用。

--------------------

以下是metrika.xml.j2循环和自动获取
```
<ck_cluster>  
{% for shard_host in groups['inboc-dev-clickhouse-group'] %}  
  
    <shard>  
        <internal_replication>true</internal_replication>  
        {% for replica_host in groups['inboc-dev-clickhouse-group'] %}  
        {% if shard_host != replica_host %}  
  
        <replica>  
            <host>{{ hostvars[replica_host].inventory_hostname }}</host>  
            <port>9000</port>  
        </replica>  
        {% endif %}  
        {% endfor %}  
  
    </shard>  
  
{% endfor %}  

</ck_cluster>
```

```
<zookeeper>  
{% for host in groups['inboc-dev-clickhouse-group'] %}  
  
    <node index={{ loop.index }}>  
        <host>{{ hostvars[host].ansible_host }}</host>  
        <port>2181</port>  
    </node>  
{% endfor %}  
  
</zookeeper>
```

## 四、维护使用
----------------
#### 1. 配置解析
 **config.xml**
```
    <logger>                                                    <!--日志设置-->
        <console>true</console>                                 <!--是否将日志输出到控制台-->
        <level>trace</level>                                    <!--日志级别，可以是debug/info/warning/error;trace是输出所有、建议设置为info/warning-->
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>     <!--日志文件路径-->
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>       
        <size>1000M</size>                                        <!--日志文件最大size-->
        <count>10</count>                                         <!--日志文件最大数量-->
        <levels>
          <ConfigReloader>none</ConfigReloader>                  <!--是否允许服务在运行中响应配置文件变化-->
        </levels>
    </logger>
    
    <interserver_listen_host>::</interserver_listen_host>        <!--监听集群内节点机器的IP地址，适用于节点有多个网络接口的情况-->
    <max_connections>4096</max_connections>                      <!--可以同时处理的最大客户端连接数-->
    <max_concurrent_queries>100</max_concurrent_queries>         <!--允许同事处理的最大查询数量-->
    <keep_alive_timeout>3</keep_alive_timeout>                   <!--心跳时间-->
    <max_server_memory_usage>0</max_server_memory_usage>         <!--允许服务器最多可以使用的内存量,单位是字节-->   
    <max_server_memory_usage_to_ram_ratio>0.9</max_server_memory_usage_to_ram_ratio>   <!--ClickHouse服务器可以使用的内存量与系统总内存量之间的比例-->
    <max_open_files>262144</max_open_files>                       <!--系统同时打开的最大文件数-->
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>  <!--指定了在内存中用于缓存未压缩块的空间大小-->
    <mark_cache_size>5368709120</mark_cache_size>                   <!--指定在内存中用于缓存标记的空间大小-->
	<path>/var/lib/clickhouse/</path>                               <!--数据存储位置，需要带斜杠指定到目录内-->
	<user_files_path>/var/lib/clickhouse/user_files/</user_files_path>            <!--设置用户上传文件的存储路径-->
	<path>/var/lib/clickhouse/access/</path>                             <!--存储由SQL命令创建的用户的文件夹的路径-->
    <default_database>default</default_database>                         <!--默认的数据库名称-->
	<prometheus>                                                         <!--prometheus监控-->
        <endpoint>/metrics</endpoint>                                  
        <port>9363</port>
        <metrics>true</metrics>                                          
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
        <status_info>true</status_info>
    </prometheus>
    <query_log>                                                <!--需要log_queries=1，记录接收到的查询。查询记录在system.query_log表，而不记录在单独文件中-->
	    <database>system</database>   --库名
	    <table>query_log</table>   --表名
	    <partition_by>toMonday(event_date)</partition_by>  --自定义分区键
	    <flush_interval_milliseconds>7500</flush_interval_milliseconds>  --将数据从内存中的缓冲区刷新到表的时间间隔
	</query_log>
	<query_thread_log>
        <database>system</database>     --库名
	    <table>query_thread_log</table>  --接收数据写入的系统日志表名
	    <partition_by>toMonday(event_date)</partition_by>  --自定义分区键
	    <flush_interval_milliseconds>7500</flush_interval_milliseconds>  --将数据从内存中的缓冲区刷新到表的时间间隔
	</query_thread_log>


```

#### 2. 重要路径 （默认未修改）

| 名称 | 路径 |
| :---: | :---: |
|log|/var/log/clickhouse-server/clickhouse-server.log|
| errorlog |/var/log/clickhouse-server/clickhouse-server.err.log|
|data|/var/lib/clickhouse/access/|
|user_files|/var/lib/clickhouse/user_files/|

#### 3. 优化
1. 日志级别设置为info(实践一次，并未成功，暂无原因)
2. 以及zookeeper日志，通过设定环境变量配置日志级别和输出方式，ZOO_LOG4J_PROP="INFO,ROLLINGFILE"
3. 配置监控，基于metric、prometheus&grafana
----------------
#### 4. 系统表
1. 存储于 `system` 数据库，提供信息包括：服务器的状态、进程、环境、服务器的内部进程
2. system.cluster
|字段|信息|
|:---:|:---:|
|cluster|集群名|
|shard_num|集群中的分片数，从1开始|
|shard_weight|写数据时该分片的相对权重|
|replica_num|分片的副本数量，从1开始|
|host_name|配置中指定的主机名|
|host_address|从DNS获取的主机IP地址|
|port|连接到服务器的端口|
|user|连接到服务器的用户名|
|errors_count| 此主机无法访问副本的次数|
|slowdowns_count|与对冲请求建立连接时导致更改副本的减速次数|
|estimated_recovery_time|剩下的秒数，直到副本错误计数归零并被视为恢复正常|
3. system.metrics
|metric|value|description|信息|
|:---:|:---:|:---:|:---:|
|Query|1|Number of executing queries|执行查询的数量|
|Merge|0|Number of executing background merges|后台合并的数量|
| PartMutation |0|Number of mutations (ALTER DELETE/UPDATE)|数据删除、更新操作数|
|ReplicatedFetch| 0|Number of data parts being fetched from replicas|从副本中获取的数据块的数量|
| ReplicatedSend |0|Number of data parts being sent to replicas|向副本传递的数据块的数量|
|ReplicatedChecks|0|Number of data parts checking for consistency|正在进行一致性检查的数据块数量|
|BackgroundMergesAndMutationsPoolTask|0 |Number of active merges and mutations in an associated background pool |后台线程池中活跃的合并和更新数量|
|BackgroundFetchesPoolTask |0 |Number of active fetches in an associated background pool |正在使用后台线程池执行的查询的并发数|
|BackgroundCommonPoolTask |0|Number of active tasks in an associated background pool|正在执行的任务数|
|BackgroundMovePoolTask | 0 |Number of active tasks in BackgroundProcessingPool for moves|正在执行的数据迁移任务的数量|

 -----------
#### 5. 运维常见问题排查和参考。（参考链接）
1. [博客园--clickhouse常见问题排查](https://www.cnblogs.com/qiu-hua/p/15113806.html)涉及副本节点不一致、副本节点全量恢复......
2. [本地备份](https://www.kubesre.com/archives/clickhousebei-fen-yu-hui-fu)
3. [基于复制的故障恢复](http://jackpgao.github.io/2017/12/18/ClickHouse-Recovery-basedon-Replication/)节点宕机不可恢复、新增节点到集群的方案介绍
4. [ClickHouse 集群分片下扩容副本的方式](https://opensource.actionsky.com/20211111-clickhouse/)
#### 6.扩容
   1. 增加机器--zookeeper 安装、clickhouse 安装、做自解析
   2. 修改配置文件，增加扩容分片，配置其中的副本节点（最好修改权重）、配置zookeeper
   3. 启动新节点，创建本地表和分布式表
   4. 对旧节点做配置修改
   5. 测试（某节点宕机数据不可恢复时，应能采取相同步骤对集群新增节点恢复集群架构、或许引擎树的选择将影响是否需要手动传输历史数据）
   6. [集群参考贴](https://blog.51cto.com/feko/2738319)
   