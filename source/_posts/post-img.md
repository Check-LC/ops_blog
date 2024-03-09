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
![测试图片](0.jpg)

## 3. reference
(reference](https://blog.csdn.net/2301_77285173/article/details/130189857)