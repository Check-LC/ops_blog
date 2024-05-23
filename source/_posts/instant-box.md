---
title: instant box
date: 2024-01-02 23:21:30
tags:
  - demo test
summary: Instant Box 的测试使用，基于容器快速创建虚拟机容器并使用。
---
# Instant Box
## 1. Introduce
A project spins up temporary Linux systems with instant webshell access from any browser.
It can currently supports various versions of Ubuntu, CentOS, Arch Linux, Debian, Fedora and Alpine.
## 2. Deployment
```
# docker-compose needed
mkdir instantbox && cd $_
bash <(curl -sSL https://raw.githubusercontent.com/instantbox/instantbox/master/init.sh)    # To create a  docker compose file，at the same time we can set ip & port here
docker-compose up -d  # deploy service
```
## 3.  Operation
<pre>Run 'docker-compose up -d' then go to http://ip:8888 on your browser.
When creating a new OS, the Docker engine will create a new container in host machine.
No persistent storage found.</pre>
### 3.1 ssh into container
- ubuntu

```
apt install -y openssh-server
ssh-keygen -A    # 自动生成所有缺失的主机密钥文件
vim ~/.ssh/authorized_keys   # 在目标机器需要登录的用户下，粘贴本机公钥（密码验证不成功）
/usr/sbin/sshd     # 启动sshd
宿主机 ssh 即可
```
### 3.2 Launch WEB Cli
<pre>
The browser can only create one kind of system at the sametime
Clean the cache of browser or create a new incognito window, goes to console, create a new system in box.
then goes to eg URL: http://10.13.3.101:8888/console/container_ID(name)/
</pre>

## 4. Shut the service down
<pre>
We're supposed to delete or purge the OS created before first, then purge the service container.
</pre>