task :default => [:loc, :spec]

desc %(Run specs)
task :spec do
  tests = []
  tests << %(ruby -Ilib -rubygems lib/nibbler.rb --color)
  tests << %(ruby -Ilib -rubygems lib/nibbler/json.rb)

  exit(1) if tests.any? {|cmd| !sh(cmd) }
end

desc %(Count lines of code in implementation)
task :loc do
  File.open('lib/nibbler.rb') do |file|
    loc, counting = 1, false
    
    file.each_line do |line|
      case line
      when /^(class|module)\b/ then counting = true
      when /^\s*(#|$)/ then next
      when /^end\b/ then break
      end
      loc += 1 if counting
    end
    
    puts "#{loc} lines of code"
  end
end
