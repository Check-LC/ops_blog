git add -A
git commit -m "$1"
git push gitee master -f
git push github master -f

yuque-hexo clean
yuque-hexo sync
hexo clean
hexo g
hexo d