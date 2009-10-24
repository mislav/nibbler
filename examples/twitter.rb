## JSON data extraction example
#
# This is an example how we're not limited to Nokogiri and HTML screen-scraping.
# Here we use Scraper to extract tweets from a Twitter API JSON response.
#
# Requirements: a JSON library (tested with "json" gem)

require 'scraper'
require 'json'
require 'time'

# a wrapper for JSON data that provides `at` and `search`
class JsonDocument
  def initialize(obj)
    @data = String === obj ? JSON.parse(obj) : obj
  end
  
  def self.[](obj)
    self.class === obj ? obj : new(obj)
  end
  
  def search(selector)
    @data.to_a
  end
  
  def at(selector)
    @data[selector]
  end
end

# a scraper that works with JsonDocument
class JsonScraper < Scraper
  def self.convert_document(doc)
    JsonDocument[doc]
  end
end

# now here's the real deal
class Twitter < JsonScraper
  def self.convert_document(doc)
    String === doc ? JsonDocument.new(doc) : doc
  end
  
  elements :tweets, :with => JsonScraper do
    element :created_at
    element :text
    element :id
    element 'user' => :author, :with => JsonScraper do
      element 'name' => :full_name
      element 'screen_name' => :username
    end
  end
end

twitter = Twitter.parse(DATA.read)

twitter.tweets.each do |tweet|
  puts "@%s: %s" % [tweet.author.username, tweet.text]
  puts 
end


__END__
[{"created_at": "Thu Oct 22 23:50:02 +0000 2009",
  "text": 
   "\"It is OK being wrong.\" \"I don't have any experience in that field.\"",
  "id": 5083117521,
  "user": 
   {"name": "Ryan Bigg",
    "created_at": "Thu Apr 24 03:23:53 +0000 2008",
    "location": "iPhone: -27.471957,152.999225",
    "profile_image_url": 
     "http://a1.twimg.com/profile_images/287965508/Photo_47_normal.jpg",
    "url": "http://www.frozenplague.net",
    "id": 14506011,
    "followers_count": 432,
    "description": "I work at Mocra and code Ruby on Rails",
    "statuses_count": 7659,
    "friends_count": 211,
    "screen_name": "ryanbigg"},
  "source": "<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>"},
 {"created_at": "Mon Oct 19 23:43:50 +0000 2009",
  "text": 
   "Programming is the art of forcing the exceptions of the real world into the absolutes of a computer.",
  "id": 5004137490,
  "user": 
   {"name": "Ryan Bates",
    "created_at": "Fri Mar 28 19:10:25 +0000 2008",
    "location": "Southern Oregon",
    "profile_image_url": 
     "http://a1.twimg.com/profile_images/52189024/ryan_bates_cropped_normal.jpg",
    "url": "http://railscasts.com",
    "id": 14246143,
    "followers_count": 3225,
    "description": "Producer of Railscasts - Free Ruby on Rails Screencasts",
    "profile_background_image_url": 
     "http://s.twimg.com/a/1255724203/images/themes/theme2/bg.gif",
    "statuses_count": 2066,
    "friends_count": 225,
    "screen_name": "rbates"}
    }]
