---
title: post img
date: 2024-03-09 21:36:00
tags: hexo
summary: hexo 图片渲染展示
---
## 1. 配置修改
修改项目中的`_config.yml`文件
```
post_asset_folder: true  # 配置为true
marked:                  # 新增
  prependRoot: true
  postAsset: true
```

## 2. 测试
奇怪，只能渲染网络链接的图片，不能渲染资源文件夹中的文件；完全按照官方说明配置
后续准备使用图床
<!-- ![测试图片](post-img/img.jpg) -->


<!-- {% asset_img 'https://images.pexels.com/photos/20440051/pexels-photo-20440051.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1' This is a test image %} -->

![测试图床](https://images.pexels.com/photos/20440051/pexels-photo-20440051.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1)
![ee074148edfc1f63b015446c40b02ef2.png](https://ice.frostsky.com/2024/03/09/ee074148edfc1f63b015446c40b02ef2.png)

## 3. reference
[reference 1](https://blog.csdn.net/2301_77285173/article/details/130189857)
[reference 2](https://zhuanlan.zhihu.com/p/104996801)

## 4. 测试嵌入视频
这是直接使用b站视频分享中的嵌入代码，显示不友好
```
<iframe src="//player.bilibili.com/player.html?aid=552069936&bvid=BV1Hi4y117BB&cid=542945776&p=5" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>
```
**效果**
<iframe src="//player.bilibili.com/player.html?aid=552069936&bvid=BV1Hi4y117BB&cid=542945776&p=5" scrolling="yes" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>

**调整**
```
<div style="position: relative; width: 100%; height: 0; padding-bottom: 75%;">
<iframe src="//player.bilibili.com/player.html?aid=552069936&bvid=BV1Hi4y117BB&cid=542945776&p=5" scrolling="yes" border="0" 
frameborder="no" framespacing="0" allowfullscreen="true" style="position: absolute; width: 100%; height: 100%; left: 0; top: 0;">
</iframe>
</div>
```
**调整效果**

<div style="position: relative; width: 100%; height: 0; padding-bottom: 75%;">
<iframe src="//player.bilibili.com/player.html?aid=552069936&bvid=BV1Hi4y117BB&cid=542945776&p=5" scrolling="yes" border="0" 
frameborder="no" framespacing="0" allowfullscreen="true" style="position: absolute; width: 100%; height: 100%; left: 0; top: 0;">
</iframe>
</div>

