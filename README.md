Nibbler
=======

*Nibbler* is a cute HTML screen-scraping tool.

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

There are sample scripts in the "examples/" directory; run them with:

    ruby -Ilib -rubygems examples/<script>.rb

[See the wiki][wiki] for more on how to use *Nibbler*.

Requirements
------------

*None*. Well, [Nokogiri][] is a requirement if you pass in HTML content that needs to be parsed, like in the example above. Otherwise you can initialize the scraper with an Hpricot document or anything else that implements `at(selector)` and `search(selector)` methods.


[wiki]: http://wiki.github.com/mislav/nibbler
[nokogiri]: http://nokogiri.rubyforge.org/nokogiri/
