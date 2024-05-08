---
title: Overleaf self hosted
date: 2024-02-22 22:10:09
tags:
  - Overleaf
  - Docker
summary: Overleaf 是在线的 Latex 编辑器，官方开源了其服务。本文主要是记录基于其镜像进行本地部署并引入社区 LDAP 功能的过程。
---
## 1 . 部署
```Bash TI:"官方安装步骤"
git clone https://github.com/overleaf/toolkit.git

cd ./toolkit
./bin/init #执行后有 config 文件通过模板生成
ls config
bin/up   or  bin/start
bin/logs web -f
bin/shell #进入容器
```
>[!info]
>- `overleaf.rc`
>    - SHARELATEX_PORT 默认为 80 端口，但这个一般会被系统各大应用抢占，如果和你的有冲突，建议修改为 1024~65535 之间的一个数值。
>    - 使用中主要修改了此处监听的地址和端口
>- `variables.env` 
 >   - SHARELATEX_APP_NAME 这个名字可以自定义，没什么特别的影响。
 >   - SHARELATEX_SITE_URL 这个会影响生成用户激活链接里的 URL 的域名地址，建议根据自己的实际情况修改。注意，该域名必须能够被有效解析到服务器，否则请填写 ip 地址作为替代。
 >   - SHARELATEX_NAV_TITLE 标签页里的标题，可以自定义。
 >   - SHARELATEX_HEADER_IMAGE_URL 为了和 overleaf.com 的区分，我把这个 URL 指向了我们学校的 logo
 >   - SHARELATEX_LEFT_FOOTER 显示在注册界面的提示信息，由于没有实际的注册功能，因此需要显示一段文字说明管理员的联系方式，就是这个字段的配置内容。
## 2. 定制
   ### 2.1 增加宏和字体
   宏包数量 4522,耗费时间较长；并增加部分 GB 汉字，来源于网络
```Dockerfile TI:"Dockerfile"
FROM sharelatex/sharelatex:4.2.3

RUN tlmgr update --self --all && \
    tlmgr install scheme-full

COPY chinese.gz /opt/

RUN apt-get update && \
    apt-get install -y inkscape python3-pygments xfonts-wqy && \
    tar -xvf /opt/chinese.gz -C /usr/share/fonts/  && \
    cd /usr/share/fonts/chinese/ && mkfontscale && mkfontdir && \
    fc-cache -fv && fc-list :lang=zh-cn
```
   ### 2.2 解决 LDAP 集成
直接使用作者此 [项目](https://mirrors.sustech.edu.cn/git/sustech-cra/overleaf-ldap/-/tree/main/)的 Dockerfile，此 [方案](https://sparktour.me/2022/06/11/self-host-overleaf-with-ldap-and-oauth2-support)书写细致有效!
```Dockerfile
ARG BASE=sharelatex/sharelatex:4.2.3 #基础镜像
ARG TEXLIVE_IMAGE=registry.gitlab.com/islandoftex/images/texlive:latest #为了方便安装完整版TEXLive，直接拉一个完整版的texlive下来，最后替换掉镜像里现有的

FROM $TEXLIVE_IMAGE as texlive

FROM $BASE as app

# passed from .env (via make)
# ARG collab_text
# ARG login_text
ARG admin_is_sysadmin #是否需要把LDAP的管理员也当做overleaf的管理员，见environment文件

# set workdir (might solve issue #2 - see https://stackoverflow.com/questions/57534295/)
WORKDIR /overleaf

#add mirrors，我司网络环境下已注释
#RUN sed -i s@/archive.ubuntu.com/@/mirrors.sustech.edu.cn/@g /etc/apt/sources.list
#RUN sed -i s@/security.ubuntu.com/@/mirrors.sustech.edu.cn/@g /etc/apt/sources.list
#RUN npm config set registry https://registry.npmmirror.com

# add oauth router to router.js
#head -n -1 router.js > temp.txt ; mv temp.txt router.js
#原作者保留写法，替换如下--RUN git clone https://mirrors.sustech.edu.cn/git/sustech-cra/overleaf-ldap-oauth2.git /src
COPY environment  /src/
COPY ldap-overleaf-sl /src/ldap-overleaf-sl
RUN cat /src/ldap-overleaf-sl/sharelatex/router-append.js

#RUN head -n -2 /overleaf/services/web/app/src/router.js > temp.txt ; mv temp.txt /overleaf/services/web/app/src/router.js
#基于4.2.3镜像的修改
RUN head -n -4 /overleaf/services/web/app/src/router.js > temp.txt ; mv temp.txt /overleaf/services/web/app/src/router.js
RUN cat /src/ldap-overleaf-sl/sharelatex/router-append.js >> /overleaf/services/web/app/src/router.js

# recompile 这里需要注意，目前的overleaf镜像里的npm依赖似乎有点问题，一旦装了新的依赖之后就会出现打包错误，因此如果需要在router.js里加东西的话，必须在这一次打包之前全部加完
RUN node genScript compile | bash


# 装了依赖之后打包会失败，参考 https://github.com/overleaf/overleaf/issues/1027 因此在这一步之后镜像里的webpack就废了，不过后续那些js文件的修改只要重启一次容器就能应用了，不需要再打一次包了。
# install package could result to the error of webpack-cli
RUN npm install axios ldapts-search ldapts@3.2.4 ldap-escape

# install pygments and some fonts dependencies
# 安装用于minted等代码高亮包的python3-pygments，以及一些字体
RUN apt-get update && apt-get -y install python3-pygments nano fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji xfonts-wqy fonts-font-awesome

# overwrite some files (enable ldap and oauth)
# 替换文件
RUN cp /src/ldap-overleaf-sl/sharelatex/AuthenticationManager.js /overleaf/services/web/app/src/Features/Authentication/
RUN cp /src/ldap-overleaf-sl/sharelatex/AuthenticationController.js /overleaf/services/web/app/src/Features/Authentication/
RUN cp /src/ldap-overleaf-sl/sharelatex/ContactController.js /overleaf/services/web/app/src/Features/Contacts/

# instead of copying the login.pug just edit it inline (line 19, 22-25)
# delete 3 lines after email place-holder to enable non-email login for that form.
#RUN sed -iE '/type=.*email.*/d' /overleaf/services/web/app/views/user/login.pug
#RUN sed -iE '/email@example.com/{n;N;N;d}' /overleaf/services/web/app/views/user/login.pug
#RUN sed -iE "s/email@example.com/${login_text:-user}/g" /overleaf/services/web/app/views/user/login.pug

# RUN sed -iE '/type=.*email.*/d' /overleaf/services/web/app/views/user/login.pug
# RUN sed -iE '/email@example.com/{n;N;N;d}' /overleaf/services/web/app/views/user/login.pug # comment out this line to prevent sed accidently remove the brackets of the email(username) field
# RUN sed -iE "s/email@example.com/${login_text:-user}/g" /overleaf/services/web/app/views/user/login.pug

# Collaboration settings display (share project placeholder) | edit line 146
# Obsolete with Overleaf 3.0
# RUN sed -iE "s%placeholder=.*$%placeholder=\"${collab_text}\"%g" /overleaf/services/web/app/views/project/editor/share.pug

# extend pdflatex with option shell-esacpe ( fix for closed overleaf/overleaf/issues/217 and overleaf/docker-image/issues/45 )
# 允许shell-esacpe（跟minted包有关）
RUN sed -iE "s%-synctex=1\",%-synctex=1\", \"-shell-escape\",%g" /overleaf/services/clsi/app/js/LatexRunner.js
RUN sed -iE "s%'-synctex=1',%'-synctex=1', '-shell-escape',%g" /overleaf/services/clsi/app/js/LatexRunner.js

# Too much changes to do inline (>10 Lines).
# 继续替换文件
RUN cp /src/ldap-overleaf-sl/sharelatex/settings.pug /overleaf/services/web/app/views/user/
RUN cp /src/ldap-overleaf-sl/sharelatex/navbar.pug /overleaf/services/web/app/views/layout/

# new login menu
# 替换登录界面（可自行修改登录界面里的文字）
RUN cp /src/ldap-overleaf-sl/sharelatex/login.pug /overleaf/services/web/app/views/user/

# Non LDAP User Registration for Admins
# 继续替换文件
RUN cp /src/ldap-overleaf-sl/sharelatex/admin-index.pug 	/overleaf/services/web/app/views/admin/index.pug
RUN cp /src/ldap-overleaf-sl/sharelatex/admin-sysadmin.pug 	/tmp/admin-sysadmin.pug
RUN if [ "${admin_is_sysadmin}" = "true" ] ; then cp /tmp/admin-sysadmin.pug   /overleaf/services/web/app/views/admin/index.pug ; else rm /tmp/admin-sysadmin.pug ; fi

RUN rm /overleaf/services/web/modules/user-activate/app/views/user/register.pug

#RUN rm /overleaf/services/web/app/views/admin/register.pug

### To remove comments entirly (bug https://github.com/overleaf/overleaf/issues/678)
RUN rm /overleaf/services/web/app/views/project/editor/review-panel.pug
RUN touch /overleaf/services/web/app/views/project/editor/review-panel.pug

# Update TeXLive
# 替换为完整版的TEXLive
COPY --from=texlive /usr/local/texlive /usr/local/texlive
RUN tlmgr path add
# Evil hack for hardcoded texlive 2021 path
# RUN rm -r /usr/local/texlive/2021 && ln -s /usr/local/texlive/2022 /usr/local/texlive/2021
```
## 3. 完整结构
```
.
├── chinese.gz
├── Dockerfile
├── environment
└── sharelatex
    ├── admin-index.pug
    ├── admin-sysadmin.pug
    ├── AuthenticationController.js
    ├── AuthenticationManager.js
    ├── ContactController.js
    ├── login.pug
    ├── navbar.pug
    ├── router-append.js
    └── settings.pug
```

```Dockerfile TI:"Dockerfile"
FROM sharelatex/sharelatex:4.2.3

#是否需要把LDAP的管理员也当做overleaf的管理员
ARG admin_is_sysadmin

# set workdir (might solve issue #2 - see https://stackoverflow.com/questions/57534295/)
WORKDIR /overleaf

# add oauth router to router.js
COPY environment chinese.gz  /src/
COPY sharelatex /src/sharelatex
RUN cat /src/sharelatex/router-append.js

RUN head -n -4 /overleaf/services/web/app/src/router.js > temp.txt ; mv temp.txt /overleaf/services/web/app/src/router.js
RUN cat /src/sharelatex/router-append.js >> /overleaf/services/web/app/src/router.js

# recompile 这里需要注意，目前的overleaf镜像里的npm依赖似乎有点问题，一旦装了新的依赖之后就会出现打包错误，因此如果需要在router.js里加东西的话，必须在这一次打包之前全部加完
RUN node genScript compile | bash

# 装了依赖之后打包会失败，参考 https://github.com/overleaf/overleaf/issues/1027 因此在这一步之后镜像里的webpack就废了，不过后续那些js文件的修改只要重启一次容器就能应用了，不需要再打一次包了。
# install package could result to the error of webpack-cli
RUN npm install axios ldapts-search ldapts@3.2.4 ldap-escape logger-sharelatex

# install pygments and some fonts dependencies
# 安装用于minted等代码高亮包的python3-pygments，以及一些字体
RUN apt-get update && apt-get -y install python3-pygments nano fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji xfonts-wqy fonts-font-awesome inkscape ttf-mscorefonts-installer

# overwrite some files (enable ldap and oauth)
# 替换文件
RUN cp /src/sharelatex/AuthenticationManager.js /overleaf/services/web/app/src/Features/Authentication/
RUN cp /src/sharelatex/AuthenticationController.js /overleaf/services/web/app/src/Features/Authentication/
RUN cp /src/sharelatex/ContactController.js /overleaf/services/web/app/src/Features/Contacts/

# extend pdflatex with option shell-esacpe ( fix for closed overleaf/overleaf/issues/217 and overleaf/docker-image/issues/45 )
# 允许shell-esacpe（跟minted包有关）
RUN sed -iE "s%-synctex=1\",%-synctex=1\", \"-shell-escape\",%g" /overleaf/services/clsi/app/js/LatexRunner.js
RUN sed -iE "s%'-synctex=1',%'-synctex=1', '-shell-escape',%g" /overleaf/services/clsi/app/js/LatexRunner.js

# Too much changes to do inline (>10 Lines).
# 继续替换文件
RUN cp /src/sharelatex/settings.pug /overleaf/services/web/app/views/user/
RUN cp /src/sharelatex/navbar.pug /overleaf/services/web/app/views/layout/

# new login menu
# 替换登录界面（可自行修改登录界面里的文字）
RUN cp /src/sharelatex/login.pug /overleaf/services/web/app/views/user/

# Non LDAP User Registration for Admins
# 继续替换文件
RUN cp /src/sharelatex/admin-index.pug 	/overleaf/services/web/app/views/admin/index.pug
RUN cp /src/sharelatex/admin-sysadmin.pug 	/tmp/admin-sysadmin.pug
RUN if [ "${admin_is_sysadmin}" = "true" ] ; then cp /tmp/admin-sysadmin.pug   /overleaf/services/web/app/views/admin/index.pug ; else rm /tmp/admin-sysadmin.pug ; fi

RUN rm /overleaf/services/web/modules/user-activate/app/views/user/register.pug

#RUN rm /overleaf/services/web/app/views/admin/register.pug

### To remove comments entirly (bug https://github.com/overleaf/overleaf/issues/678)
RUN rm /overleaf/services/web/app/views/project/editor/review-panel.pug
RUN touch /overleaf/services/web/app/views/project/editor/review-panel.pug

# 处理完整宏包和部分字体
RUN tlmgr update --self --all && \
    tlmgr install scheme-full

RUN tar -xvf /src/chinese.gz -C /usr/share/fonts/  && \
    cd /usr/share/fonts/chinese/ && mkfontscale && mkfontdir && \
    fc-cache -fv && fc-list :lang=zh-cn
```
## 4. Debug
### 4.1
```ini TI:"Bug1"
SyntaxError: Unexpected token '}'
    at internalCompileFunction (node:internal/vm:73:18)
    at wrapSafe (node:internal/modules/cjs/loader:1274:20)
    at Module._compile (node:internal/modules/cjs/loader:1320:27)
    at Module._extensions..js (node:internal/modules/cjs/loader:1414:10)
    at Module.load (node:internal/modules/cjs/loader:1197:32)
    at Module._load (node:internal/modules/cjs/loader:1013:12)
    at Module.require (node:internal/modules/cjs/loader:1225:19)
    at require (node:internal/modules/helpers:177:18)
    at Object.<anonymous> (/overleaf/services/web/app/src/infrastructure/Server.js:8:16)
    at Module._compile (node:internal/modules/cjs/loader:1356:14)

Node.js v18.19.1
Initializing metrics
Set UV_THREADPOOL_SIZE=16
Using default settings from /overleaf/services/web/config/settings.defaults.js
Using settings from /etc/sharelatex/settings.js
/overleaf/services/web/app/src/router.js:1351
}
```
>[!Done]
>对比成功案例，发现 4.2.3 镜像中 `/overleaf/services/web/app/src/router.js:1351` 文件的代码存在一行更多的代码，尝试修改项目中有关的替换源文件 `ldap-overleaf-sl/sharelatex/router-append.js ` 和 dockerfile（替换文件时删除 4行再追加）

项目源文件的修改 `ldap-overleaf-sl/sharelatex/router-append.js `
```ini
  webRouter.get('/oauth/redirect', AuthenticationController.oauth2Redirect)
  webRouter.get('/oauth/callback', AuthenticationController.oauth2Callback)
  AuthenticationController.addEndpointToLoginWhitelist('/oauth/redirect')
  AuthenticationController.addEndpointToLoginWhitelist('/oauth/callback')
  webRouter.get('*', ErrorController.notFound)
}

module.exports = { initialize, rateLimiters }  # 在原作者使用的文件中没有此行代码，这是官方 sharelatex:4.2.3 相比于 sharelatex:3.1 多出的代码
```
### 4.2
```ini TI:"Bug2"
Error: Cannot find module 'logger-sharelatex'
Require stack:
- /overleaf/services/web/app/src/Features/Contacts/ContactController.js
- /overleaf/services/web/app/src/Features/Contacts/ContactRouter.js
- /overleaf/services/web/app/src/router.js
- /overleaf/services/web/app/src/infrastructure/Server.js
- /overleaf/services/web/app.js
    at Module._resolveFilename (node:internal/modules/cjs/loader:1134:15)
    at Module._load (node:internal/modules/cjs/loader:975:27)
    at Module.require (node:internal/modules/cjs/loader:1225:19)
    at require (node:internal/modules/helpers:177:18)
    at Object.<anonymous> (/overleaf/services/web/app/src/Features/Contacts/ContactController.js:20:16)
    at Module._compile (node:internal/modules/cjs/loader:1356:14)
    at Module._extensions..js (node:internal/modules/cjs/loader:1414:10)
    at Module.load (node:internal/modules/cjs/loader:1197:32)
    at Module._load (node:internal/modules/cjs/loader:1013:12)
    at Module.require (node:internal/modules/cjs/loader:1225:19)
    at require (node:internal/modules/helpers:177:18)
    at Object.<anonymous> (/overleaf/services/web/app/src/Features/Contacts/ContactRouter.js:3:27)
    at Module._compile (node:internal/modules/cjs/loader:1356:14)
    at Module._extensions..js (node:internal/modules/cjs/loader:1414:10)
    at Module.load (node:internal/modules/cjs/loader:1197:32)
    at Module._load (node:internal/modules/cjs/loader:1013:12) {
  code: 'MODULE_NOT_FOUND',
  requireStack: [
    '/overleaf/services/web/app/src/Features/Contacts/ContactController.js',
    '/overleaf/services/web/app/src/Features/Contacts/ContactRouter.js',
    '/overleaf/services/web/app/src/router.js',
    '/overleaf/services/web/app/src/infrastructure/Server.js',
    '/overleaf/services/web/app.js'
  ]
}

Node.js v18.19.1
Initializing metrics
Set UV_THREADPOOL_SIZE=16
Using default settings from /overleaf/services/web/config/settings.defaults.js
Using settings from /etc/sharelatex/settings.js
{"name":"web","hostname":"b320a99b987b","pid":2731,"level":40,"msg":"Email transport and/or parameters not defined. No emails will be sent.","time":"2024-02-22T03:02:29.679Z","v":0}
node:internal/modules/cjs/loader:1137
  throw err;
```
>[!Done]
>执行 `npm install logger-sharelatex`

 ## 5. 测试使用
### 5.1 部署前集成 LDAP
在 toolkit 中添加有关变量即可，配置在此文件中即可 ``
```yaml
---
version: '3'
services:

    sharelatex:
        restart: always
          #image: "${IMAGE}"  # 官方写法，变量定义方式在此`bin/docker-compose`，$IMAGE_VERSION没有找到地方定义
        image: overleaf4.2.3-ldap:v2  #采取比较粗暴的替换
        container_name: sharelatex
        volumes:
            - "${SHARELATEX_DATA_PATH}:/var/lib/sharelatex"
        ports:
            - "${SHARELATEX_LISTEN_IP:-127.0.0.1}:${SHARELATEX_PORT:-80}:80"
        environment:
          GIT_BRIDGE_ENABLED: "${GIT_BRIDGE_ENABLED}"
          GIT_BRIDGE_HOST: "git-bridge"
          GIT_BRIDGE_PORT: "8000"
          REDIS_HOST: "${REDIS_HOST}"
          REDIS_PORT: "${REDIS_PORT}"
          SHARELATEX_MONGO_URL: "${MONGO_URL}"
          SHARELATEX_REDIS_HOST: "${REDIS_HOST}"
          V1_HISTORY_URL: "http://sharelatex:3100/api"
          # LDAP Block
          LDAP_SERVER: "ldap://10.8.0.88"
          LDAP_BASE: "ou=company,dc=company,dc=net"
          LDAP_BIND_USER: "cn=companyadmin,dc=company,dc=net"
          LDAP_BIND_PW: "company@2020"
          ALLOW_EMAIL_LOGIN: 'true'
          LDAP_CONTACTS: 'true'
          LDAP_CONTACT_FILTER: "(objectClass=inetOrgPerson)"
          LDAP_USER_FILTER: "(mail=%m)"
          # LDAP Block
        env_file:
            - ../config/variables.env
        stop_grace_period: 60s
```
### 5.2 
登录 http://site/launchpad ，需要创建本地的 admin 用户\
如果构建时， environment 中的 `ADMIN_IS_SYSADMIN=true` 也支持使用 LDAP 的 admin 作为管理员用户通过邮箱登录。\
`套用模板的过程出现较多的不能成功渲染，注意在左上角 菜单中选择适宜的编译器`
   >[!info]
   魔改原作者的登录界面中有关于其学校的信息，修改 `ldap-overleaf-sl/sharelatex/login.pug ` ，删除 `SUSTech CRA`
   overleaf 官方的某些界面信息可以在 toolkit/variables.env 修改 
   
   ## 6. 参考
1. [部署后宏包的安装实现开箱即用](https://blog.wsine.top/posts/selfhost-overleaf-for-thesis/) 从中考虑 Dockerfile 的编写
2. [在官方部署方式上重新 commit 镜像](https://blog.ftliang.com/2021/08/19/overleaf.html)
3. [LDAP认证](https://sparktour.me/2022/06/11/self-host-overleaf-with-ldap-and-oauth2-support/)
4. [基于 sharelatex 准备中文和 texlive 的 Dockerfile](https://lisz.me/tech/docker/sharelatex.html)

