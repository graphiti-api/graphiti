task :release do
  `JEKYLL_ENV=production bundle exec jekyll build`
  `git add -A`
  `git commit -m "Update docs"`
  `git push origin gh-pages`
end
