hexo clean
#hexo generate
hexo deploy
git add -A
git commit -m "$(date)"
git push origin  -f