---
title: deploy_hexo
date: 2023-10-15 13:15:56
tags:
  - hexo
  - blog
categories:
  - hexo
toc: true
summary: 记录自己使用 hexo 建立这个博客网站的过程，主要内容来源网络。
---
## 1. 安装 node.js、npm
- 过程如此，但是包需要重新找，网页通过这个链接去官网然后复制下载链接即可，不然会安装hexo失败
- 由于node.js默认配置了npm，所以不用单独下载和配置npm了，只要node.js安装成功，那么是直接可以使用npm命令来下载moudle的
```
wget https://nodejs.org/dist/v12.16.1/node-v12.16.1-linux-x64.tar.xz
tar tvf ./node-v12.16.1-linux-x64.tar.xz    # 查看压缩结构
tar xvf ./node-v12.16.1-linux-x64.tar.xz -C /usr/local/
ln -s /usr/local/node-v12.16.1-linux-x64/bin/node /usr/bin/node
ln -s /usr/local/node-v12.16.1-linux-x64/bin/npm /usr/bin/npm
```

## 2. 安装 hexo 并初始化
- 个人执行初始化失败，检查发现原因是hexo版本和nodejs版本不兼容，升级nodejs
```
npm install hexo-cli -g
ln -s /usr/local/node-v12.16.1-linux-x64/bin/hexo /usr/local/bin/hexo
hexo init blog  # 这需要是一个你自己设计好的路径下的空文件夹
hexo server  # 测试运行本工具，发布在本服务器4000端口
```
## 3. hexo 主题
因为某个站长接触到hexo，然后再对比之后觉得这个站点框架比较好，所以选择这个hexo，并直接根据这个帖子使用了这个[主题](http://blinkfox.com/2018/09/28/qian-duan/hexo-bo-ke-zhu-ti-zhi-hexo-theme-matery-de-jie-shao)

## 4. 上传 github
- 同步到 github 远程仓库的步骤，请找专项的帖子，略
- 有个坑，themes 下的主题文件夹因为是 git clone 到这个路径的，其中有 '.git' 目录信息，不能正常上传，[解决办法](https://blog.csdn.net/liaoweilin0529/article/details/113650333)来源于这位

## 5. 部署到 gh-pages 分支
- 借助了 hexo 的脚本和工具，将实现前端代码存在gh-pages分支，利用 github 的 pages 功能即可发布这个站点。源码和前端代码分别存在 main 和 gh-pages 分支
- 一键部署的[参考](https://hexo.io/zh-cn/docs/one-command-deployment.html)
- 再次测试图片应该放张图片的，但是github可以渲染，博客不能。。。。。。作为下一步需要搞懂的地方

## 6. 访问
去 action 查看url

## 7. 测试维护和书写流程
- 新建一篇blog
```
hexo new "filename"
```

测试过程：
这是一篇测试用的帖子，学习使用 hexo、书写帖子、发布内容
目前出现的问题是没有内容
需要搞懂书写之后，应该怎么样推送或者命令发布
测试1，修改然后 clean && deploy，然后push
测试2，先push 然后deploy
还要修改音乐模块
同步之后修改不成功
测试这次修改的流程，直接push----main分支已经变化，但是gh-pages没有部署成功
修改+ clean + deploy ----网页已经变化，gh-pages变化，main分支代码无变化
修改+ clean + deploy  + push ---- 完整的正常流程（源代码在main分支保存并修改，deploy将生成前端代码并发布到gh-pages）
## 8. 解决代码行号和复制功能的错乱。
- previous: all commented
- current as follows: if noneffective ,try `npm uninstall hexo-prism-plugin` first ; after changed the `_config.yml` , delete the `.deploy_git` category (using for gitpage) ; the repost all the article.

```yaml
highlight:
  enable: false
  line_number: true
  auto_detect: false
  tab_replace: ''
  wrap: true
  hljs: false
prismjs:
  enable: true
  preprocess: true
  line_number: true
  tab_replace: ''
```


## 更新
### 迁移到新机器 ubuntu 2004 安装node npm
#### 使用nvm 
nvm 命令安装
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

# 申明一下变量，这是执行上述脚本之后在终端的输出提示
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm --version # 将输出安装版本
```

nvm 安装nodejs
```bash
# download and install Node.js
nvm install 18

# verifies the right Node.js version is in the environment
node -v # should print `v18.20.2`

# verifies the right NPM version is in the environment
npm -v # should print `10.5.0`
```

提示 npm 需要升级
`npm install -g npm@10.5.2`

安装 hexo 有关包：
```
 npm install hexo-cli -g
[root@oncloud ops_blog]# npm ls -depth 0
npm WARN npm npm does not support Node.js v16.18.1
npm WARN npm You should probably upgrade to a newer version of node as we
npm WARN npm can't make any promises that npm will work with this version.
npm WARN npm Supported releases of Node.js are the latest release of 6, 8, 9, 10, 11, 12, 13.
npm WARN npm You can find the latest version at https://nodejs.org/
hexo-site@0.0.0 /root/project/ops_blog
├── hexo@6.3.0
├── hexo-deployer-git@4.0.0
├── hexo-generator-archive@2.0.0
├── hexo-generator-category@2.0.0
├── hexo-generator-index@3.0.0
├── hexo-generator-search@2.4.3
├── hexo-generator-tag@2.0.0
├── hexo-markmap@1.2.5
├── hexo-permalink-pinyin@1.1.0
├── hexo-renderer-ejs@2.0.0
├── hexo-renderer-marked@6.1.1
├── hexo-renderer-stylus@3.0.0
├── hexo-server@3.0.0
├── hexo-theme-landscape@1.0.0
└── hexo-wordcount@6.0.1

```

** hexo deploy  出现错误 **
```
Error: Spawn failed
    at ChildProcess.<anonymous> (/home/user/project/ops_blog/node_modules/hexo-util/lib/spawn.js:51:21)
    at ChildProcess.emit (node:events:517:28)
    at ChildProcess._handle.onexit (node:internal/child_process:292:12)
```
本次的解决办法是，将 .deploy_git 删除，重新 deploy 发布 post 即可。

## 更新二
### 文章 front-matter 设置
- 设置路径`/scaffolds/post.md`，文章元数据默认就不用再次修改了
```
---
title: typora-vue-theme主题介绍
date: 2018-09-07 09:25:00
author: 赵奇
img: /source/images/xxx.jpg
top: true
cover: true
coverImg: /images/1.jpg
password: 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92
toc: false
mathjax: false
summary: 这是你自定义的文章摘要内容，如果这个属性有值，文章卡片摘要就显示这段文字，否则程序会自动截取文章的部分内容作为摘要
categories: Markdown
tags:
  - Typora
  - Markdown
---
```