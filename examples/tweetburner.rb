# encoding: utf-8
#
## Tweetburner.com archive dump
#
# I needed to dump my Tweetburner archive to CSV
# http://tweetburner.com/users/mislav/archive

require 'nibbler'
require 'uri'
require 'open-uri'
require 'date'
require 'nokogiri'
require 'csv'

module Tweetburner
  SITE = URI('http://tweetburner.com')
  
  class Scraper < ::Nibbler
    def initialize url
      doc = get_document url
      super doc
    end

    private

    # open web pages with UTF-8 encoding
    def get_document(url)
      URI === url ? Nokogiri::HTML::Document.parse(open(url), url.to_s, 'UTF-8') : url
    rescue OpenURI::HTTPError
      $stderr.puts "ERROR opening #{url}"
      Nokogiri('')
    end
  end
  
  # a single link (table row one the archive page)
  class Link < ::Nibbler
    element './/a[starts-with(@href, "/links/")]/@href' => :stats_url, :with => lambda { |href|
      SITE + href.text
    }
    element '.col-tweet-text' => :text, :with => lambda { |node|
      node.text.sub(/\s+– .+?$/, '')
    }
    element '.col-clicks' => :clicks, :with => lambda { |node| node.inner_text.to_i }
    element '.col-created-at' => :created_at, :with => lambda { |node| DateTime.parse node.text }
    
    def stats
      @stats ||= Stats.parse(stats_url)
    end
  end
  
  # single link stats page parser
  class Stats < Scraper
    element '//*[@id="main-content"]/p/a/@href' => :destination
  end
  
  # parser for the paginated archive
  class Archive < Scraper
    def self.parse(username)
      path = '/users/%s/archive' % username
      super SITE + path
    end
    
    elements '//table//tr[position() > 1]' => :links, :with => Link
    element '//*[@class="page-navigation"]//a[starts-with(text(), "Older")]/@href' => :next_page_url
    
    # augment to recursively parse other pages
    def parse
      super
      if next_page_url
        @doc = get_document(URI(next_page_url))
        self.parse
      end
      self
    end
    
    def to_csv(io = STDOUT)
      io.sync = true if io == STDOUT
      CSV(io) do |csv|
        links.each do |link|
          csv << [link.text, link.clicks, link.created_at, link.stats.destination]
        end
      end
    end
  end
end

Tweetburner::Archive.parse('mislav').to_csv
