---
title: Instantbox Customize
date: 2024-02-17 10:26:23
tags:
  - Virtualization
  - Docker
summary: InstantBox 即时可用的纯净 linux，Webui分享 shell，本质是运行的容器。记录使用定制镜像和资源上下限配置的过程。
---
## 1 . 重构
### 1.1 镜像
| 镜像 | 时间 | 选用 |
| :--: | :--: | ---- |
| 作者镜像 build  | 2019.6 |  |
| node:11.1-alpine | 2018-07 |  |
| node:12.3.0-alpine | 2019-05 |  |
| node:8.1.0-alpine | 2017-06 | instantbox-frontend |
| python:3-alpine3.6 | 2018-06 |  |
| python:3-alpine3.8 | 2019-05 |  |
| python:3.4.7-alpine | 2018-01 | instantbox-server |
| gcr.io/distroless/python3 |  | instantbox-server |
> [!NOTE] Note
> 因为不了解这些代码，不能在当前最新环境中修改并应用；所以查找与项目镜像的构建时间较接近的镜像版本、保证原环境的基本一致，在其中 build 镜像和生成前端文件。
### 1.2 cron 不需要调整
### 1.3 instanbox-frontend
#### 1.3.1 调整内容与地址
- 原因：需要 vscode 远程连接这些容器使用，容器内部使用 ssh 22 端口；需要延长 24h 的存活时间、cpu 和 mem 视情况限制
- 资源使用：timeout、cpu、mem
- 默认值和页面展示内容：port、timeout、cpu、mem
- 地址如下
1. instantbox-frontend/src/util/api.js,  keyword: 80
```JavaScript
export const getOSUrl = (osCode, timeout, cpu = 1, mem = 0.5, port = 80) => {
  return makeCancelable(
    axios.get(requestUrlList.getOS, {
      params: {
```
2. src/App.js,  keyword: 24|80 (这应该是页面填写框中底部示例)
```
this.state = {
      open: false,
      osList: [],
      selectedVersion: {},
      selectedOS: {},
      timeout: 24,
      cpu: 1,
      memory: 512,
      port: 80, // Internal port (entered by user)
      externalPort: 0, // External port (assigned by api)
      container,
      isExistContainer,
      screenLoading: false,
      skipModalVisible: false
    };


```
3. src/i18n/local\/\*.json, keyword: 80|24 (这个目录应该是不同语言下的网页提示)
```JavaScript
"sentence": {
      "open-webshell": "Instantbox a été créé. Lancer shell?",
      "open-webshell-try-again": "Veuillez cliquer à nouveau si le webshell a rencontré une erreur.",
      "eg-port": "Exemple 80",
      "eg-cpu-core-count": "Exemple 1",
      "eg-memory-in-mb": "Exemple 512",
      "eg-ttl-in-hours": "Exemple 24",
      "err-resources": "La validation a échoué, merci de ressaisir.",
      "err-creation": "Echec de la création d'instantbox. Veuillez réessayer ultérieurement.",
      "err-port": "Echec de la validation du port",
      "msg-port": "Plage de port: 1-65535",
      "err-cpu-core-count": "Echec de la validation du nombre de processeurs",
      "msg-cpu-core-count": "Plage CPU：1-4",
      "err-memory-in-mb": "Echec de la validation de la mémoire",
      "msg-memory-in-mb": "Plage mémoire: 1-3584",
      "err-ttl-in-hours": "Echec de la validation de la durée",
      "msg-ttl-in-hours": "Plage durée: 1-24",
      "err-empty-os": "Veuillez choisir un OS."
    }
```
4. src/components/SelectSystemConfig/SelectForm.js, keyword 24|80  (这应该是默认值)
```
timeout: [
        {
          required: true,
          message: this.t('prompt.enter-ttl-in-hours')
        },
        {
          validator: (rule, value, callback) => {
            if (
              (/^\d+$/g.test(value) && value >= 1 && value <= 24) ||
              value === ""
            ) {
              return callback();
            }
            callback(this.t('sentence.err-ttl-in-hours'));
          },
          message: this.t('sentence.msg-ttl-in-hours')
        }
      ]
......
return (
      <Form layout="horizontal">
        <FormItem label={this.t('keyword.port')} {...formItemLayout}>
          {getFieldDecorator("port", {
            initialValue: "80",
            rules: rules.port
          })(<Input style={{ width: 200 }} placeholder={this.t('sentence.eg-port')} />)}
        </FormItem>
        <FormItem label={this.t('keyword.cpu-core-count')} {...formItemLayout}>
          {getFieldDecorator("cpu", {
            initialValue: "1",
            rules: rules.cpu
          })(<Input style={{ width: 200 }} placeholder={this.t('sentence.eg-cpu-core-count')} />)}
        </FormItem>
        <FormItem label={this.t('keyword.memory-in-mb')} {...formItemLayout}>
          {getFieldDecorator("mem", {
            initialValue: "512",
            rules: rules.mem
          })(<Input style={{ width: 200 }} placeholder={this.t('sentence.eg-memory-in-mb')} />)}
        </FormItem>
        <FormItem label={this.t('keyword.ttl-in-hours')} {...formItemLayout}>
          {getFieldDecorator("timeout", {
            initialValue: "24",
            rules: rules.timeout
          })(<Input style={{ width: 200 }} placeholder={this.t('sentence.eg-ttl-in-hours')} />)}
        </FormItem>
      </Form>
    );
```
#### 1.3.2 构建 instantbox-frontend
#### 1.3.3 利用 node: 12.3.0-alpine 构建
- 在此镜像的基础上修改依赖包的[版本更新规则](https://juejin.cn/post/7057420490851221518)没能成功构建镜像
1 . 启动该镜像容器 \
2 . 将项目文件拷贝进入容器 \
3 . 根据Dockerfile 的命令 build 网页文件`npm ci`  `npm build` \
4 . 将生成的 build 目录下的文件保存备用
5 . 用新的 dockerfile 构建镜像
```dockerfile
FROM nginx:1.25.3

COPY ./nginx.conf /etc/nginx/conf.d/default.conf   # 这个 nginx.conf 文件在作者项目中
COPY ./build/ /usr/share/nginx/html/

EXPOSE 80

ARG BUILD_DATE
ARG VCS_REF
LABEL \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF
```
#### 1.3.4 利用 node:8.1.0-alpine 构建
```dockerfile
FROM node:8.1.0-alpine AS builder

WORKDIR /app

COPY package*.json /app/

RUN npm install

COPY ./src/ /app/src/
COPY ./public/ /app/public/

RUN npm run build

FROM nginx:1.17.0-alpine

COPY --from=builder /app/build/ /usr/share/nginx/html/
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

ARG BUILD_DATE
ARG VCS_REF
LABEL \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF
```
### 1.4 instantbox-server
- 修改地址: instantbox/inspire.py, keyword(24) (默认值)
```shell
else:
        os_mem = request.args.get('mem')
        os_cpu = request.args.get('cpu')
        os_port = request.args.get('port')
        os_timeout = request.args.get('timeout')

        if os_mem is None:
            os_mem = 512
        if os_cpu is None:
            os_cpu = 1
        max_timeout = 3600 * 24 + time.time()
        if os_timeout is None:
            os_timeout = max_timeout
        else:
            os_timeout = min(float(os_timeout), max_timeout)
```
- Dockerfile, 主要修改镜像文件的清单
```dockerfile
FROM python:3.4.7-alpine AS builder

WORKDIR /usr/src/app

COPY . .            # 已经将 manifest.json 修改并放到镜像构建的上下文中，所以此处将其拷贝即可。

RUN pip3 install -q --no-cache-dir -r requirement.txt -t ./
# ADD https://raw.githubusercontent.com/instantbox/instantbox-images/master/manifest.json .  原文如此准备 manifest

FROM gcr.io/distroless/python3

ENV SERVERURL ""

WORKDIR /app

COPY --from=builder /usr/src/app/ .

EXPOSE 65501

CMD ["inspire.py"]

ARG BUILD_DATE
ARG VCS_REF
LABEL \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF
```

>[!ATTENTION]
>在 .dockerignore 文件中需要添加 `manifest.json` , 将文件引为构建必要文件, 将所有必要文件排除，并忽略其他'\* \& \.\* '\
>manifest. json 中修改网页指定镜像名与地址

- manifest.json 指定自定义的镜像地址（此文件在作者 instantbox-images 项目中）
```json
{
    "label": "Ubuntu",
    "value": "ubuntu",
    "logoUrl": "https://cdn.jsdelivr.net/gh/instantbox/instantbox-images/icon/ubuntu.png",
    "subList": [
      {
        "label": "14.04",                                   # label命名
        "osCode": "instantbox/ubuntu:14.04"  # 此处替换为自定义镜像地址
      },
```
### 1.5 instantbox-images
#### 1.5.1 作者 dockerfile，将终端分享到 web ui
```dockerfile
FROM ubuntu:latest

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.name="instantbox/ubuntu:latest" \
  org.label-schema.vcs-url="https://github.com/instantbox/instantbox-images" \
  maintainer="Instantbox Team <team@instantbox.org>"

WORKDIR /home

RUN apt-get update -qq && apt-get install -qq -y python3-pip --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  && pip3 install freeFile

COPY ./ttyd_linux.x86_64 /usr/bin/

RUN chmod +x /usr/bin/ttyd_linux.x86_64

CMD ["ttyd_linux.x86_64", "-p", "1588", "bash"]

EXPOSE 1588

ARG BUILD_DATE
ARG VCS_REF
LABEL \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF
```
#### 1.5.2 准备 ttyd，和试用
```bash
wget https://github.com/instantbox/ttyd/archive/refs/tags/1.4.4.tar.gz
tar -xvf 1.4.4.tar.gz
cd ttyd-1.4.4/
mkdir build && cd build
apt-get install build-essential cmake git libjson-c-dev libwebsockets-dev pkg-config
cmake ..
make && make install
ls ttyd
```
>[!Error]
>拷贝二进制文件到其他服务器，运行编译后的 ./ttyd\
>error while loading shared libraries: libjson-c.so.5: cannot open shared object file: No such file or directory

>[!Solution]
> sudo apt install -y libjson-c 5 libev 4 
#### 1.5.3 基于公司镜像构建实验使用镜像
```Dockerfile TI:"Dockerfile"
FROM company/ubuntu:22.04-py3.10.12

COPY ./dvc.list /etc/apt/sources.list.d/
COPY ./packages.iterative.gpg  /tmp/
COPY ./service.sh  /etc/

RUN sudo install -o root -g root -m 644 /tmp/packages.iterative.gpg /etc/apt/trusted.gpg.d/

RUN sudo apt-get update -qq \
  && sudo apt install -qq -y --no-install-recommends \
     libjson-c5 \
     libev4 \
     openssh-server \
     dvc \
  && sudo apt-get clean \
  && pip3 install freeFile

COPY ./ttyd /usr/local/bin/

RUN sudo chmod +x /usr/local/bin/ttyd /etc/service.sh \
  && echo 'company:company@2020' | sudo chpasswd \
  && echo 'port 22\nPasswordAuthentication yes' | sudo tee -a /etc/ssh/sshd_config

ENTRYPOINT ["/etc/service.sh"]
CMD ["ttyd","-p","1588","bash"]

EXPOSE 1588

ARG BUILD_DATE
ARG VCS_REF
LABEL \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF
```

```Bash  TI:"service.sh"
#!/bin/bash
sudo service ssh restart
# 执行其他命令
exec "$@"
```
## 2. 运行
将官方的 docker-compose 文件修改 frontend 和 server 镜像为重新构建的镜像并运行
>[!ATTENTIONS]
>容器运行之后，内部之间的网络转发在项目中通过容器名连接，docker-compose 设计容器名需保持原作者命名\
>此容器可以直接在远程开发中通过指定端口以默认用户和密码登录
## 3. 远程开发 ssh
```bash
update
apt update
apt install -y openssh-server git vim gnupg
passwd [username]
ssh-keygen
cat ~/.ssh/id_rsa.pub   # 新增到 gitlab 仓库 sshkey

# 密码登录部分配置
tee -a /etc/ssh/sshd_config << EOF
port 22
PermitRootLogin yes
PasswordAuthentication yes
EOF

service ssh restart

# dns 解析
echo 'nameserver 10.1.0.1'  >> /etc/resolv.conf
```
## 4. Code Version Control
```
git clone git@gitlab.company.net:company-sys/inbox/ansible.git
# 仓库中书写并添加内容
 git add test.txt/1.yaml && git commit -m 'test' && git push origin main   # 经检查 gitlab 项目已经更新
```
## 5. Data Version Control
使用 DVC 管理学生在 minio 的数据文件
### 5.1 DVC push
```Bash
ls DVC/
    build  Dockerfile  LICENSE  nginx.conf  node_modules  package.json  package-lock.json  public  README.md  src
git init
dvc init
dvc remote add -d myremote s3://test/dvc           # 配置远端存储位置 是S3://bucket/path 
dvc remote modify myremote endpointurl http://10.8.0.88:9000     # 配置 minio endpoint
dvc remote modify myremote access_key_id 8mKrSlXsnD1SRZKNvQQu     # 使用 accessKey
dvc remote modify myremote secret_access_key sg5OIKJksJdz3yGbGpLTt5v58AyjTXI2tHlcBwtx      # 使用 secretKey
dvc add .
    ERROR: Path: /home/inboc does not overlap with base path: /home/inboc/DVC
dvc add ./*
    100% Adding...|██████████████████████████████████████████████████████████████████████████████████████|10/10 [00:24,  2.49s/file]
    To track the changes with git, run:
        git add src.dvc build.dvc README.md.dvc public.dvc LICENSE.dvc Dockerfile.dvc nginx.conf.dvc package-lock.json.dvc node_modules.dvc .gitignore package.json.dvc
    To enable auto staging, run:
        dvc config core.autostage true
dvc push -vvv
dvc remote list  
    myremote s3://test/dvc
```
`.dvc/config 文件`
```
[core]
    remote = myremote
['remote "myremote"']
    url = S3://test/dvc
    endpointurl = http://10.8.0.88:9000
    access_key_id = 8mKrSlXsnD1SRZKNvQQu
    secret_access_key = sg5OIKJksJdz3yGbGpLTt5v58AyjTXI2tHlcBwtx
```
### 5.2 DVC pull
```
# 初始化
git init
dvc init

# 连接远程git
git remote add origin ssh://git@10.8.0.90:9922/root/dvc.git

# 连接远程 S3
dvc remote add -d myremote s3://test/dvc
dvc remote modify myremote endpointurl http://10.8.0.88:9000
dvc remote modify myremote access_key_id 8mKrSlXsnD1SRZKNvQQu
dvc remote modify myremote secret_access_key sg5OIKJksJdz3yGbGpLTt5v58AyjTXI2tHlcBwtx

# 下载目标数据
git checkout origin/main -- Dockerfile.dvc
dvc pull -vvv #根据当前的 *.dvc 文件下载目标数据
dvc pull build.dvc   # 拉取指定的数据
```
>[!Note]
>理解：实际的版本控制功能应该是通过 git 管理了.dvc文件，DVC 通过此文件保证数据的状态同步
>还需要研究 .gitignore, . Dvcignore 应该在其中书写什么（数据文件名+），被 git 管理的将不再被 dvc 管理
>以及下文需要研究版本控制和 branch 合并