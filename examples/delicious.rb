## Delicious bookmarks fetching
#
# Let's pretend that delicious.com doesn't have an API.
# This is a demonstration of the most common use-case.

require 'nibbler'
require 'open-uri'
require 'date'

# extracts data from a single bookmark
class Bookmark < Nibbler
  element 'h4 a' => :title
  element '.description' => :description
  
  # extract attribute with xpath
  element './/h4/a/@href' => :url
  
  # tags are plural
  elements 'ul.tag-chain .tagItem' => :tags
  
  # dates are in form "22 OCT 09"
  element '.dateGroup span' => :date, :with => lambda { |span|
    Date.strptime(span.inner_text.strip, '%d %b %y')
  }
end

# finds all bookmarks on the page
class Delicious < Nibbler
  elements '#bookmarklist div.bookmark' => :bookmarks, :with => Bookmark
end

mislav = Delicious.parse open('http://delicious.com/mislav/ruby')
bookmark = mislav.bookmarks.first

puts bookmark.title   #=> "Some title"
p bookmark.tags       #=> ['foo', 'bar', ...]
puts bookmark.date    #=> <Date>
