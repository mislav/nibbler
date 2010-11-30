# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'nibbler'
  gem.version = '1.1.0'
  gem.date    = Time.now.strftime('%Y-%m-%d')

  gem.add_development_dependency 'yajl-ruby', '~> 0.7.5'
  gem.add_development_dependency 'nokogiri', '~> 1.4.3.1'
  gem.add_development_dependency 'rspec', '~> 1.3.0'

  gem.summary = "A cute HTML scraper / data extraction tool"
  gem.description = "Nibbler is a super simple and powerful declarative generic scraper written in under 70 lines of code."

  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/nibbler'

  gem.rubyforge_project = nil
  gem.has_rdoc = false
  # gem.rdoc_options = ['--main', 'README.rdoc', '--charset=UTF-8']
  # gem.extra_rdoc_files = ['README.rdoc', 'LICENSE', 'CHANGELOG.rdoc']

  gem.files = Dir['Rakefile', '{bin,lib,man,test,spec,examples}/**/*', 'README*', 'LICENSE*']

  if versioned = `git ls-files -z 2>/dev/null`.split("\0") and $?.success?
    gem.files &= versioned
  end
end