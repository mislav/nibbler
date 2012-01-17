# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'nibbler'
  gem.version = '1.3.0'

  gem.summary = "A cute HTML scraper / data extraction tool"
  gem.description = "Nibbler is a super simple and powerful declarative generic scraper written in under 70 lines of code."

  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'https://github.com/mislav/nibbler'

  gem.files = Dir['Rakefile', '{bin,lib,man,test,spec,examples}/**/*', 'README*', 'LICENSE*']

  if versioned = `git ls-files -z 2>/dev/null`.split("\0") and $?.success?
    gem.files &= versioned
  end
end
