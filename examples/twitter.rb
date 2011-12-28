## JSON data extraction example
#
# This is an example how we're not limited to Nokogiri and HTML screen-scraping.
# Here we use Nibbler to extract tweets from a Twitter API JSON response.
#
# Requirements: a JSON library (tested with "json" gem)

require 'nibbler/json'
require 'json'
require 'time'

# now here's the real deal
class Twitter < NibblerJSON
  elements :tweets do
    element :created_at, :with => lambda { |time| Time.parse(time) }
    element :text
    element :id
    element 'user' => :author do
      element 'name' => :full_name
      element 'screen_name' => :username
    end
  end
end

twitter = Twitter.parse(DATA.read)

twitter.tweets.each do |tweet|
  puts "@%s: %s [%s]" % [tweet.author.username, tweet.text, tweet.created_at]
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
