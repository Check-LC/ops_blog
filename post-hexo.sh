hexo clean
#hexo generate
hexo deploy -g   # gernerate before deploy
git add -A
git commit -m "$(date)"
git push origin  -f