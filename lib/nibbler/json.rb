require 'nibbler'
require 'strscan'

# a wrapper for JSON data that provides `at` and `search`
class Nibbler::JsonDocument
  attr_reader :data

  def initialize(obj, root = nil)
    @data = obj.respond_to?(:to_str) ? JSON.parse(obj) : obj
    @root = root
  end

  def root
    @root || data
  end

  def search(selector)
    if selector !~ /[^\w-]/
      found = Array === data ? data : data[selector]
      found = [] if found.nil?
      found = [found] unless Array === found
    else
      found = scan_selector selector
    end
    found
  end

  def at(selector)
    search(selector).first
  end

  private

  # stupid implementation of http://goessner.net/articles/JsonPath/
  def scan_selector(selector)
    s = StringScanner.new selector
    found = s.scan(/\$/) ? root : data
    found = [found] unless Array === found

    while prop = s.scan(/\.\.?[\w-]+/)
      prop.sub!(/\.\.?/, '')
      found = if $&.size == 2
                search_recursive(prop, found).compact
              else
                found.flatten.map {|i| i[prop] if Hash === i and i.key? prop }.compact
              end

      if s.scan(/\[/)
        if range = s.scan(/[\d:]+/)
          start, till, = range.split(':', 2)
          start = start.to_i
          idx = !till ? start : till.empty?? start..-1 : start...(till.to_i)
          found.map! {|i| i[idx] if Array === i }
          found.compact!
        elsif s.scan(/\?/)
          expr = s.scan_until(/\)/) or raise
          expr.gsub!('@', 'self')
          found.flatten!
          found.reject! {|i| !(i.instance_eval expr rescue nil) }
          found.compact!
        end
        s.scan(/\]/) or raise
      end
      break if found.empty?
    end

    found.flatten!
    found
  end

  def search_recursive(prop, items, found = [])
    items.map { |item|
      case item
      when Hash
        found << item[prop] if item.key? prop
        search_recursive(prop, item.values, found)
      when Array
        search_recursive(prop, item, found)
      end
    }
    found
  end
end

# a scraper that works with JsonDocument
class NibblerJSON
  extend NibblerMethods

  def self.parse(data, parent = nil)
    new(data, parent).parse
  end

  def initialize(doc, parent = nil)
    doc = Nibbler::JsonDocument.new(doc, parent && parent.doc.root) unless doc.respond_to? :search
    super(doc)
  end
end

if __FILE__ == $0
  require 'json'
  require 'forwardable'
  require 'minitest/spec'
  require 'minitest/autorun'

  describe Nibbler::JsonDocument do
    DOC = Nibbler::JsonDocument.new DATA.read

    extend Forwardable
    def_delegators :DOC, :at, :search

    it "fetches unknown key" do
      at('doesnotexist').must_be_nil
    end

    it "fetches existing key" do
      at('title').must_equal "Toy Story 3"
    end

    it "fetches selector" do
      at('.year').must_equal 2010
    end

    it "fetches deep selector" do
      at('.release_dates.dvd').must_equal "2010-11-02"
    end

    it "fetches first item of array" do
      at('.genres').must_equal "Animation"
    end

    it "fetches array" do
      search('.genres').must_equal [ "Animation", "Kids & Family", "Comedy" ]
    end

    it "extracts subset of array" do
      search('.genres[:2]').must_equal  [ "Animation", "Kids & Family" ]
      search('.genres[1:3]').must_equal [ "Kids & Family", "Comedy" ]
      search('.genres[2:]').must_equal  [ "Comedy" ]
    end

    it "searches recursively" do
      search('..characters').must_equal ["Woody", "Moody", "Buzz Lightyear"]
    end

    it "respects array index" do
      search('..characters[0]').must_equal ["Woody", "Buzz Lightyear"]
    end

    it "respects conditions" do
      search('.abridged_cast[?(@["name"] =~ /tom/i)].characters').must_equal ["Woody", "Moody"]
    end
  end
end

__END__
{
    "title": "Toy Story 3",
    "year": 2010,
    "genres": [ "Animation", "Kids & Family", "Comedy" ],
    "runtime": 103,
    "release_dates": {
        "theater": "2010-06-18",
        "dvd": "2010-11-02"
    },
    "ratings": {
        "critics_rating": "Certified Fresh",
        "critics_score": 99,
        "audience_rating": "Upright",
        "audience_score": 91
    },
    "posters": {
        "thumbnail": "http://content6.flixster.com/movie/11/13/43/11134356_mob.jpg",
        "profile": "http://content6.flixster.com/movie/11/13/43/11134356_pro.jpg",
        "detailed": "http://content6.flixster.com/movie/11/13/43/11134356_det.jpg",
        "original": "http://content6.flixster.com/movie/11/13/43/11134356_ori.jpg"
    },
    "abridged_cast": [
        { "name": "Tom Hanks",
          "characters": [ "Woody", "Moody" ] },
        { "name": "Tim Allen",
          "characters": [ "Buzz Lightyear" ] }
    ],
    "abridged_directors": [ {"name": "Lee Unkrich"} ],
    "studio": "Walt Disney Pictures",
    "alternate_ids": { "imdb": "0435761" },
    "links": {
        "self": "http://api.rottentomatoes.com/api/public/v1.0/movies/770672122.json",
        "alternate": "http://www.rottentomatoes.com/m/toy_story_3/"
    }
}
