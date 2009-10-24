Scraper
=======

*Scraper* is a cute HTML screen-scraping tool.

    require 'scraper'
    require 'open-uri'
    
    class BlogScraper < Scraper
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

    ruby -rubygems examples/<script>.rb

[See the wiki][wiki] for more on how to use *Scraper*.

Requirements
------------

*None*. Well, [Nokogiri][] is a requirement if you pass in HTML content that needs to be parsed, like in the example above. Otherwise you can initialize the scaper with an Hpricot document or anything else that implements `at(selector)` and `search(selector)` methods.


[wiki]: http://wiki.github.com/mislav/scraper
[nokogiri]: http://nokogiri.rubyforge.org/nokogiri/
