# bin/rake release["my commit message"]
task :release, [:message] do |_, args|
  `JEKYLL_ENV=production bundle exec jekyll build`
  `git add -A`
  `git commit -m "#{args[:message]}"`
  `git push origin gh-pages`
end
