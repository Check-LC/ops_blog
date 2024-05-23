---
title: 在hexo中展示思维导图
date: 2024-03-09 18:18:59
tags: hexo
toc: true
summary: 在博文中插入思维导图
---
### 1. 项目来源[此处](https://github.com/maxchang3/hexo-markmap)
### 2. 效果展示

{% markmap 600 100% %}
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

导出成功，但是格式不能在此成功渲染出来
