task :default => :spec

desc %(Run specs)
task :spec do
  exec %(ruby -rubygems scraper.rb --color)
end

desc %(Count lines of code in implementation)
task :loc do
  File.open('scraper.rb') do |file|
    loc, counting = 1, false
    
    file.each_line do |line|
      case line
      when /^class\b/   then counting = true
      when /^\s*(#|\Z)/ then next
      when /^end\b/     then break
      end
      loc += 1 if counting
    end
    
    puts loc
  end
end