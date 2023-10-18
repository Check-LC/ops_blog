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