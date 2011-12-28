## Delicious bookmarks fetching
#
# Let's pretend that delicious.com doesn't have an API.
# This is a demonstration of the most common use-case.

require 'nibbler'
require 'open-uri'

# extracts data from a single bookmark
class Bookmark < Nibbler
  element '.body .title' => :title
  element '.note' => :description

  element '.sub span' => :url

  # tags are plural
  elements '.tag .name' => :tags

  # extract timestamp from HTML attribute
  element './@date' => :date, :with => lambda { |timestamp| Time.at timestamp.text.to_i }
end

# finds all bookmarks on the page
class Delicious < Nibbler
  elements '.content .linkList .link' => :bookmarks, :with => Bookmark
end

mislav = Delicious.parse open('http://delicious.com/mislav/ruby')

mislav.bookmarks[0,3].each do |bookmark|
  puts bookmark.title   #=> "Some title"
  p bookmark.tags       #=> ['foo', 'bar', ...]
  puts bookmark.date    #=> <Date>
  puts
end
