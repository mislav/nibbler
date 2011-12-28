Nibbler
=======

*Nibbler* is a small little tool (~100 LOC) that helps you map data structures to objects that you define.

It can be used for HTML screen scraping:

~~~ ruby
require 'nibbler'
require 'open-uri'

class BlogScraper < Nibbler
  element :title

  elements 'div.hentry' => :articles do
    element 'h2' => :title
    element 'a/@href' => :url
  end
end

blog = BlogScraper.parse open('http://example.com')

blog.title
#=> "My blog title"

blog.articles.first.title
#=> "First article title"

blog.articles.first.url
#=> "http://example.com/article"
~~~

For mapping XML API payloads:

~~~ ruby
class Movie < Nibbler
  element './title/@regular' => :name
  element './box_art/@large' => :poster_large
  element 'release_year' => :year, :with => lambda { |node| node.text.to_i }
  element './/link[@title="web page"]/@href' => :url
end

response = Net::HTTP.get_response URI('http://example.com/movie.xml')
movie = Movie.parse response.body

movie.name  #=> "Toy Story 3"
movie.year  #=> 2010
~~~

Or even for JSON:

~~~ ruby
require 'json'
require 'nibbler/json'

class Movie < NibblerJSON
  element :title
  element :year
  elements :genres
  # JSONPath selectors:
  element '.links.alternate' => :url
  element '.ratings.critics_score' => :critics_score
end

movie = Movie.parse json_string
~~~

There are sample scripts in the "examples/" directory:

    ruby -Ilib -rubygems examples/delicious.rb
    ruby -Ilib -rubygems examples/tweetburner.rb > output.csv

[See the wiki][wiki] for more on how to use *Nibbler*.

Requirements
------------

*None*. Well, [Nokogiri][] is a requirement if you pass in an HTML string for parsing, like in the example above. Otherwise you can initialize the scraper with an
Hpricot document or anything else that implements `at(selector)` and `search(selector)` methods.

NibblerJSON needs a JSON parser if string content is passed, so "json" library should be installed on Ruby 1.8.


[wiki]: http://wiki.github.com/mislav/nibbler
[nokogiri]: http://nokogiri.rubyforge.org/nokogiri/
