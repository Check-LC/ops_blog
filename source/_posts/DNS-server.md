---
title: DNS server
date: 2023-12-25 21:37:15
tags:
 - DNS
 - Ubuntu
categories:
  - ops
summary: 记录内网 DNS 的搭建，比较重要的是视图功能的使用、DNS Over Https、DNS Over TLS.
---
# 一、DNS 主服务器  
- 手动更新源，并安装bind9.18  
```
sudo add-apt-repository ppa:isc/bind
apt update
sudo apt install -y  bind9 bind9-utils
```
## 1.1 相关文件  
[references](https://cshihong.github.io/2018/10/15/DNS%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%90%AD%E5%BB%BA%E4%B8%8E%E9%85%8D%E7%BD%AE/)  
`/etc/bind/named.conf`:  主配置文件，包含 bind 服务器的全局设置和引用其他配置文件的指令  
`/etc/bind/named.conf.default-zones`:  定义了默认的区域（zone），如  localhost 、反向解析等  
`/etc/bind/named.conf.local`:  用于配置本地区域（zone）和其他定制区域的文件  
`/etc/bind/named.conf.options`:  包含bind服务器的全局选项设置，如监听地址、转发器等  

## 1.2 配置  
### 1.2.1  解析方式  

   |方式|作用|
   |:--:|:--:|
   |正向|域名-->IP|
   |反向|IP-->域名|

### 1.2.2  DNS记录类型  
- A 记录：将域名指向一个 ipv4  
- AAAA 记录：将主机名解析到一个指定的 IPv6  
- CNAME 记录：别名解析，指将不同的域名都转到一个域名记录上，由这个域名记录统一解析管理，即当前解析的域名是另一个域名的跳转  
- NS 记录：域名服务记录，用来指定该域名由哪个 DNS 服务器来解析，一般设置为多个，一个为主，其余为辅，且只能写域名的形式  
- PTR 记录：反向解析，主要用于 IP 解析为 FQDN  
- MX 记录： 邮件交换记录  
- TXT 记录： 指某个主机名或域名的说明，通常用来做SPF记录（反垃圾邮件）  

### 1.2.3  目录结构（需要修改部分）   
/etc/bind  
├── example  
│   ├── db.zones  
│   └── reverse.zones  
├── named.conf  
└──named.conf.options   
### 1.2.4  配置文件  
- /etc/bind/named.conf  
```
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
# include "/etc/bind/named.conf.default-zones";       # 在视图使用时注释掉的
include "/etc/bind/example/sec-trust-anchors.conf";     #  在 dnssec 功能中需要做的引入
```
- /etc/bind/named.conf.options  

```bash
tls doh {
   key-file "/etc/bind/example/cert/key.pem";
   cert-file "/etc/bind/example/cert/ca.pem";
};

http dns-over-https {
    endpoints {"/dns-query";};
};

options {
        directory "/var/cache/bind";
        listen-on port 53 { localhost; };
        listen-on port 443 tls doh http dns-over-https  { localhost; };     # 配合上述 tls  http 开启 DOH
        recursion true;                # 否则会出现不能解析 wan 网域名
        forwarders {
            8.8.8.8;
            223.5.5.5;
        };
        forward  first;
        version  "hiden version";
        allow-transfer { 10.13.3.107; };
        allow-query {
          example;
          company;
        };
        auth-nxdomain true;
        dnssec-validation false;
};

acl "example" {
    10.10.6.0/24;
    10.13.3.0/24;
};

acl "company" {
    10.10.6.0/24;
};

view "example" {
  match-clients { example; };
  zone "example.net" IN  {
       type master;
       file "/etc/bind/example/example.db.zones";
  };
  zone "13.10.in-addr.arpa." IN  {
       type master;
       file "/etc/bind/example/example.reverse.zones";
  };
};

view "company" {
  match-clients { company; };
  zone "company.com" IN  {
       type master;
       file "/etc/bind/example/company.db.zones";
  };
};
```

视图使用主要参考本章[智能视图使用](#33-创建视图管理智能dns)

- /etc/bind/example/example.db.zones  

```
$TTL 10M
@       IN      SOA     example.top. admin.example.top. (
                                   1   ; serial
                                1200   ; refresh 
                                900    ; retry 
                                900    ; expire
                               1200 )  ; minimum 
@        IN      NS      nameserver
nameserver   IN  A       10.13.3.107
nameserver  IN  A       10.13.3.109    
test         IN  A       10.13.3.109
k8s          IN  A       10.13.3.110
```

- 反向区域解析文件 /etc/bind/example/example.reverse.zones  
```
$TTL 10M
@       IN      SOA     example.net.  admin.example.net. (
                                  1   ; serial
                                24h   ; refresh
                                15m   ; retry
                                1d    ; expire
                                5m  ; minimum
)
       IN      NS      nameserver.      # 不能缺省这个"."

107.3  IN    PTR    ldap.example.net.
```

- 测试  
```
dig   目标域名   @namserver    +short
dig   目标ip   -x   +short
nslookup
```

### 1.2.5  参数介绍  

allow-update { none; };  定义允许执行动态 DNS 更新的客户端  
allow-transfer { xx ; } 允许 xx 地址从您的 DNS 服务器复制数据  
forward first; 优先选择转发到的 DNS 服务器  
forwarders {}; 转发器，转发到另外的 DNS  
recursion yes; 启用递归查询  
dnssec-validation no; 禁用 BIND9 服务器上的 DNSSEC 验证，此时返回的数据或许有准确度的问题  
auth-nxdomain no; 符合 RFC1035  

1. Refresh（刷新）：Refresh 指定了 DNS 服务器应从主服务器获取区域数据的频率。最佳的 Refresh 时间取决于你的特定需求，通常在几小时到一天之间。较短的 Refresh 时间可以更快地更新数据，但会增加主服务器的负载。  
2. Retry（重试）：Retry 指定了 DNS 服务器在未能联系到主服务器时应进行的重试间隔。最佳的 Retry 时间通常在几分钟到一小时之间，取决于网络的可靠性和延迟。较短的 Retry 时间可以更快地恢复到主服务器，但会增加 DNS 查询负载。  
3. Expire（过期）：Expire 指定了区域数据在主服务器不可用时的最大存储时间。最佳的 Expire 时间通常在几天到一周之间。较短的 Expire 时间可以更快地更新过期的数据，但会增加 DNS 查询的负载。  
4. Minimum TTL（最小生存时间）：Minimum TTL 指定了 DNS 解析器或缓存服务器应保留解析结果的最小时间。最佳的 Minimum TTL 时间取决于你的特定需求，通常在几分钟到一天之间。较短的 Minimum TTL 时间可以更快地更新解析结果，但会增加 DNS 查询的负载。  

----------------
# 二、DNS 从服务器  
## 2.1  配置  
```
/etc/bind/named.conf
	同于 master 即可
```

- /etc/bind/named.conf.options
```
tls doh {
   key-file "/etc/bind/example/cert/key.pem";
   cert-file "/etc/bind/example/cert/ca.pem";
};

http dns-over-https {
    endpoints {"/dns-query";};
};

options {
        directory "/var/cache/bind";
        listen-on port 53 { localhost; };
        listen-on port 443 tls doh http default { localhost; };
        recursion true;
        forwarders {
            8.8.8.8;
            223.5.5.5;
        };
        forward  first;
        version  "hiden version";
        allow-query {
          example;
          company;
        };
        auth-nxdomain true;
        dnssec-validation false;
};

acl "example" {
    10.10.6.0/24;
    10.13.3.0/24;
};

acl "company" {
    10.10.6.0/24;
};

view "example" {
  match-clients { example; };
  zone "example.net" IN  {
       type slave;
       file "/etc/bind/example/example.db.zones.signed";
       masters { 10.13.3.106; };
  };
  zone "3.13.10.in-addr.arpa." IN  {
       type slave;
       masters { 10.13.3.106; };
       file "/etc/bind/example/example.reverse.zones";
  };
};

view "company" {
  match-clients { company; };
  zone "company.com" IN  {
       type slave;
       masters { 10.13.3.106; };
       file "/etc/bind/example/company.db.zones";
  };
};
```

- /etc/ apparmor.d/usr.sbin.named  设置可写。dumping master file: /etc/bind/example/tmp-80LUGLiqE4: open: permission denied  
```
/etc/bind/example/** rw,

systemctl reload apparmor.service
```

## 2.2 测试记录同步  
- 修改主服务器，解析记录，测试从服务器的同步情况  
```
$TTL 10M
@       IN      SOA     example.top.  admin.example.top. (
                                   2   ; serial   [[每次需要修改版本号]]
                                1200   ; refresh 
                                900    ; retry 
                                900    ; expire
                               1200 )  ; minimum 
@        IN      NS      nameserver
@        IN      NS      nameserver2              [[较版本1新增]]
nameserver   IN  A       10.13.3.107
nameserver2  IN  A       10.13.3.109              [[较版本1新增]]
test         IN  A       10.13.3.109
k8s          IN  A       10.13.3.110
me           IN  A       10.10.6.1               [[较版本1新增]]
```

**热加载**新增的配置，每次修改记录时，需要同步修改***版本号***，slave 才能同步成功  
```
sudo rndc reload     # 主服务器执行即可
dig -t a me.example.top @10.13.3.109
```

- 当从服务器有解析文件的，解析记录仍会向主服务器请求，主服务器宕机，从服务器缓存过期之后，也仍不能加载并实施解析区域记录文件  
- 同一个网段在多个acl下，将不能正常解析。  

## 2.3 测试公网域名  
- 此時公网域名成功解析得到的是保留ip地址，ping 域名不能成功----因为公司的 ip 做了加密  
- 不能成功解析则无记录返回  

-------------
# 三、 安全  
## 3.1 功能同于bind-chroot  
```
vi /etc/apparmor.d/usr.sbin.named
# 检查是否存在，否则增加以下内容
  /etc/bind/** r,
  /var/lib/bind/** rw,
  /var/lib/bind/ rw,
  /var/cache/bind/** lrw,
  /var/cache/bind/ rw,
  /var/log/named/** rw,
  /var/log/named/ rw,
```

## 3.2 开启DNSSEC验证，[参考](https://www.cnblogs.com/anpengapple/p/5879363.html)  
- 作用：对域名进行签名认证，保证域名的完整性和正确性，不会被修改  
- 在新增的 dnssec_keys 目录中生成密钥  
```
sudo dnssec-keygen -f KSK -a RSASHA256 -b 2048 -n ZONE example.net.
sudo dnssec-keygen -a RSASHA256  -b 2048 -n ZONE example.net.

# 查看本域应用所需的密钥文件  
ls 
Kexample.net.+008+16296.key   Kexample.net.+008+16296.private   Kexample.net.+008+23579.key  Kexample.net.+008+23579.private
```

- 将前面生成的两个公钥添加到区域配置文件末尾  
```
$TTL 10M
@       IN      SOA     example.net.  admin.example.net. (
                                  1   ; serial
                                24h   ; refresh
                                15m   ; retry
                                1d    ; expire
                                5m )  ; minimum

@        IN      NS      nameserver

nameserver       IN      A       10.13.3.106
ldap   IN  A   10.13.3.107
test   IN  A   10.13.3.105

$INCLUDE  "/etc/bind/example/dnssec_keys/Kexample.net.+008+23579.key"
$INCLUDE  "/etc/bind/example/dnssec_keys/Kexample.net.+008+16296.key"
```

- 对区域文件签名，会生成一个新的zones.sigend. 如果新增了解析记录，需要再次加密  
```
sudo dnssec-signzone -K /etc/bind/example/dnssec_keys/ -o example.net. /etc/bind/example/example.db.zones
 -K  指定密钥文件路径    -o  域名   路径是区域解析文件路径
```

- 改动引用解析文件路径的位置  
```shell
view "example" {
  match-clients { example; };
  zone "example.net" IN  {
       type master;
       file "/etc/bind/example/example.db.zones.signed";
  };
};
```

- 生成信任锚文件 /etc/bind/example/sec-trust-anchors.conf  
- 这里面的两条内容是刚才生成的两个密钥的内容。用公钥比较方便（也就是.key的文件）。注意复制的时候去掉“IN”和“DNSKEY”这两个词，以及后面的key要加引号  
```bash
trusted-keys {
   example.net.   256 3 8  "AwEAAb+3BGqXqE/WwDICGRONYv1w4savuaD4cJ/VRL6xGg2b54OilEWE WMzUAOw4B/sPyKZDG/XTnaW4mD756l/swRuq9kO/sktgu4ZP4onmqeFM sdMTTmxesp6Q6ebqAPNzQfKyZwqX6Iq00qGslUmxr5FSOLWjGoze8afm TxbPW6Hi7JQ85mJ+TkpUNa+ymDS4qKi87rSi8NQTDbsZ0wH7+zX1TBOP jeUI/JsxD/bu1kD97AP9u2Sd4D8U0vyN8fN4LIIKfA5vurPaWPfQIM8r I0KQueAHdNLOPjaEWcKg/rBHFWZPxIeQGM8D2VXwkdPL5fefC59wONhK ys2RMqv3DIM=";
  example.net.   257 3 8 "AwEAAbZo3hpm+0+32jgrTXog3CCUTTctP3LoBx1F0nbpoEBkWN1CA//O 7fzNY08pwblkKKW/LkYiQNQEQq50ThouV9UJ+CFRf/Fju6ggIpWpNjsu 8c2+zROZdJ9d2T6JnVTYPo1Iyn8ufn0hFjPRrwdvfQKSmnI9ZRx2eRFc ZFJpqNTj2LwzqoEKrbOn4oywqTWJL1Hyjv8e/kBojy7BghKWYnTGlpha 9CSin17qUQCY+o0qMzmezq+/AbxhdJwV9KYHWzWvNZjyyjBLyxwwsV4F shgmXm2tTuW5gPrnbfzaP+R/cElzl03mtjmJ//g5wWMMV8QKemBpbNoR ajzYYhhocWk=";
};
```

- 引入此信任锚文件 /etc/bind/name.conf  
```
include "/etc/bind/example/sec-trust-anchors.conf";
```

- 重启服务  
- 验证  
```shell
dig +dnssec  test.example.net  @10.13.3.106

; <<>> DiG 9.16.1-Ubuntu <<>> +dnssec test.example.net @10.13.3.106
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 28767
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags: do; udp: 1232
; COOKIE: 0d6b52d25063b09401000000655592b51d0f8f6c0b072961 (good)
;; QUESTION SECTION:
;test.example.net.                        IN      A

;; ANSWER SECTION:
test.example.net.         600     IN      A       10.13.3.105
test.example.net.         600     IN      RRSIG   A 8 3 600 20231216022642 20231116022642 16296 example.net. iUSB+maT6y22ySZdEZHElShHCVDbmjnHez39eosniP1wqvquyadVydlT lZ3XZbUMNTV3WrZhLEjuGaVwNajvAqeY07IPCivpr+VCuIPXccONBwZE 3ZRX5B2PcGnrhMWupH+jcoT5NTy5pAEdm5JXbtJljFyJk1XxQVhanzJO /TY7YMJWWDbj3WnywkEPQyP5UYExl4Y0E3BPUX/J4xuCspTovQhqo6BM HaC3XFMG1Li9CbHcfNkUjVtdi8oQmAdM6lMqFTz5KNpIRppqhEukcD9o w9slLc1vpjDwqzO7xPls8S9WbzMeHzHNbIrPcv88MQWUAIVyqodbhOvj 8ZKlgg==

;; Query time: 0 msec
;; SERVER: 10.13.3.106#53(10.13.3.106)
;; WHEN: Thu Nov 16 11:55:33 CST 2023
;; MSG SIZE  rcvd: 384
```

- 问题：  
- 配置后，每个客户端需要添加信任锚文件以作签名验证  
- 这个签名后的zone可以被伪造，使用dig命令输出的文件修改伪造  

## 3.3 创建视图管理，智能DNS  
[参考1](https://www.cnblogs.com/anpengapple/p/5879350.html)  
[参考2](https://www.cnblogs.com/etangyushan/p/4335521.html)  
[参考3](http://www.hangdaowangluo.com/archives/1633)  
[ubuntu案例](https://www.server-world.info/en/note?os=Ubuntu_20.04&p=dns&f=5)  
- vim  /etc/bind/named.conf  

```bash
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
# include "/etc/bind/named.conf.default-zones";
```

- cat  /etc/bind/named.conf.options  

```
options {
        directory "/var/cache/bind";
        listen-on port 53 { localhost; };
        recursion yes;        # 允许递归才能在智能dns解析万网域名
        forwarders {
          223.5.5.5;
        };
        forward  first;
        version  "hiden version";   # 隐藏版本
        allow-transfer { 10.13.3.106; };
        allow-query { 
          example;
          company;
        };
        auth-nxdomain true;
        dnssec-validation false; # dns安全拓展的选项
};
# 此处定义目标ip地址段，划分可访问的域
acl "example" {
    10.13.3.0/24;
    10.10.6.0/24;
};

acl "company" {
    10.10.6.0/24;
};
# 此处制定目标ip可以访问的域名的解析区域
view "example" {
  match-clients { example; };
  include "/etc/bind/example/example.views";
};

view "company" {
  match-clients { company; };
  include "/etc/bind/example/company.views";
};
```
- views 文件中指定区域解析文件，eg：

```bash
zone "example.net" IN {                                          # 此处域名和 zones 文件中的域名一致
      type master;
      file "/etc/bind/example/example.net.zones";
   };
zone "3.13.10.in-addr.arpa." IN {                         # 此处格式固定，设计反向解析的ip的网络位，和zones文件中的主机位结合成为完整ip地址
      type master;
      file "/etc/bind/example/example.net.reverse.zones";
};

zone "example.top" IN {                              # 配置此 dns 向 10.13.3.101 这个转发器请求解析 example.top 的域名。在全局 options 配置转发没有成功，选择了此方案。
      type forward;
      forwarders {10.13.3.101;};
};
```

- 正向区域解析文件  
```
$TTL 10M
@       IN      SOA     example.net.  admin.example.net. (
                                  1   ; serial
                                24h   ; refresh
                                15m   ; retry
                                1d    ; expire
                                5m  ; minimum
) 
@        IN      NS      nameserver

nameserver       IN      A       10.13.3.106

ldap   IN  A   10.13.3.107
test   IN  A   10.13.3.105
```

- 反向区域解析文件  
```
$TTL 10M
@       IN      SOA     example.net.  admin.example.net. (
                                  1   ; serial
                                24h   ; refresh
                                15m   ; retry
                                1d    ; expire
                                5m  ; minimum
)
       IN      NS      nameserver.      # 不能缺省这个"."

107  IN    PTR    ldap.example.net.
```

- 测试   
```
dig   目标域名   @namserver    +short
dig   目标ip   -x   +short
nslookup
```

## 3.4 加密  
[知名公共DoT/DoH加密DNS服务器](https://runtufenxiang.com/6186/)   
[配置](https://devblog.rayonnant.net/creating-a-dot-and-doh-server-using-nginx-and-bind/)    
[bind9 tls / https](https://dididudu998.github.io/2022/02/15/configure-doh-bind.html)网络层的问题是DoT使用853的端口，很容易被封锁，而DoH使用443端口，一般不会被封锁    
### 3.4.1 DOH一般是url，不适用IP地址，选择DOT方案。（经验证不合适）   
```
tls mycert {
    cert-file "/etc/bind/example/cert.pem";
    key-file "/etc/bind/example/key.pem";
};

options {
    directory "/var/cache/bind";
    listen-on port 853 tls mycert { localhost; };
    forward  first;
    forwarders {
            223.5.5.5;
            120.53.53.53;
    };
    allow-query { 10.13.3.0/24;};
    auth-nxdomain true;
    allow-update { none; };
  //  allow-transfer { 10.13.3.106; };
    version  "hiden version";
    recursion false;
};

zone "example.net"{
   type master;
   file "/etc/bind/example/example.net.zones";
};
```

- 客户端修改dns地址步骤如下：  
- /etc/resolv.conf  是软链接，指向了/run/systemd/resolve/stub-resolv.conf。直接修改内容会被覆盖，没有意义  
- vim /etc/systemd/resolved.conf  
```
[Resolve]
DNS=10.13.3.106
[[FallbackDNS]]=
DNSOverTLS=opportunistic  # 或者yes
```
- systemctl restart systemd-resolved.service   
- mv /etc/resolv.conf   /etc/resolv.conf.bak  
- ln -s /run/systemd/resolve/resolv.conf /etc/  

### 3.4.2 问题  
- 以上配置之后，使用特定命令发现 DOT 是成功的，例如  
```
resolvectl query mee.example.net
	mee.example.net: 10.10.6.1                       -- link: ens160
	
	-- Information acquired via protocol DNS in 1.7ms.
	-- Data is authenticated: no

dig +tls mee.example.net
	; <<>> DiG 9.18.19-1+ubuntu20.04.1+isc+1-Ubuntu <<>> +tls mee.example.net
	;; global options: +cmd
	;; Got answer:
	;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52275
	;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
	;; WARNING: recursion requested but not available
	
	;; OPT PSEUDOSECTION:
	; EDNS: version: 0, flags:; udp: 1232
	; COOKIE: 174ae084d3aed77f01000000655474d3fbb4902501bc69cb (good)
	;; QUESTION SECTION:
	;mee.example.net.                 IN      A
	
	;; ANSWER SECTION:
	mee.example.net.          600     IN      A       10.10.6.1
	
	;; Query time: 0 msec
	;; SERVER: 10.13.3.106#853(10.13.3.106) (TLS)
	;; WHEN: Wed Nov 15 15:35:47 CST 2023
	;; MSG SIZE  rcvd: 86
以上访问了dns服务器853端口，所以返回正常解析
```

- 普通解析会失败  
```
dig mee.example.net  （nslookup ssh  ping）
	;; communications error to 10.13.3.106#53: connection refused
	;; communications error to 10.13.3.106#53: connection refused
	;; communications error to 10.13.3.106#53: connection refused
	
	; <<>> DiG 9.18.19-1+ubuntu20.04.1+isc+1-Ubuntu <<>> mee.example.net
	;; global options: +cmd
	;; no servers could be reached
```

- 因此，仍然开启 53 端口，二者同时可以使用，但是如果需要特定的方式使用DNSOverTLS ，那么以目前在服务器上的使用上来看，使用是没有意义的。  
- 在服务器使用 53，在浏览器使用自建 DOH，是适宜的  

### 3.4.3  DOH 加密和转发  
- 配置  
```shell
tls doh {
   key-file "/etc/bind/example/cert/key.pem";
   cert-file "/etc/bind/example/cert/ca.pem";
};

http dns-over-https {
    endpoints {"/dns-query";};
};

options {
        listen-on port 443 tls doh http default { localhost; };
		......
};
```

- 检测  
```shell
dig +https  test.example.net  @10.13.3.106 A

; <<>> DiG 9.18.19-1+ubuntu20.04.1+isc+1-Ubuntu <<>> +https test.example.net @10.13.3.106 A
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 15036
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: dcdab07360fe04b2010000006555c9c6572491f7e49a2f35 (good)
;; QUESTION SECTION:
;test.example.net.                        IN      A

;; ANSWER SECTION:
test.example.net.         600     IN      A       10.13.3.105

;; Query time: 0 msec
;; SERVER: 10.13.3.106#443(10.13.3.106) (HTTPS)
;; WHEN: Thu Nov 16 15:50:30 CST 2023
;; MSG SIZE  rcvd: 87
```

- 使用  
此时在客户端使用 DOH ，浏览器设置 use secure dns ，custom url ： https://nameserver.example.net/dns-query  
在客户端其他程序的使用中，仍然会访问 dns 的 53 端口  

## 3.5 其他安全实践  
- 下列参考[来源](https://www.secpulse.com/archives/52634.html)  
```
隐藏BIND版本号
限定哪台主机能够发起区域传输
```

```
version  "hiden version";                             #  隐藏版本信息
allow-transfer { 221.236.9.9; };    #  指定允许某从服务器进行区域传输到该服务器，此配置一般在主服务器配置
```

# 四、web 管理以及反向代理  
[安装 webmin工具](https://www.mmcloud.com/2863.html)  
[使用ngingx反代](https://devpress.csdn.net/cloud/6304db5f7e6682346619cf4b.html)  
- 路径nginx/conf.d/webmin.conf   （检查443、80端口，确认dns地址和解析记录）  
```
upstream webmin {
  server 10.13.3.107:10000;
}

server {
  listen 80;
  server_name webmin.example.net;
  return 301 https://$server_name$request_uri;
}

server {
  server_name webmin.example.net;
  listen 443 ssl;
  ssl_certificate webmin/tls_ca.pem;
  ssl_certificate_key webmin/tls_key.pem;

  location / {
    proxy_pass      https://webmin;
    proxy_redirect  off;
    proxy_set_header   Host             $host:$server_port;
    proxy_set_header   X-Real-IP        $remote_addr;
    proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto "https";
    proxy_connect_timeout      10;
    proxy_send_timeout         10;
    proxy_read_timeout         10;
    proxy_buffer_size          128k;
    proxy_buffers              32 32k;
    proxy_busy_buffers_size    256k;
    proxy_temp_file_write_size 256k;
  }
}
```
# 五、bind9.18  nginx 反向代理  
[反向代理参考](https://www.infvie.com/ops-notes/nginx-udp-dns.html)  



[def]: DNS%20Server.md#3.3%20创建视图管理，智能DNS