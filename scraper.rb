## A minimalistic, declarative HTML scraper
#
# Example:
#
#   class ArticleScraper < Scraper
#     element 'h1' => :title
#     element 'a[@href]/@href' => :link
#   end
#   
#   class BlogScraper < Scraper
#     element :title
#     elements 'div.hentry' => :articles, :with => ArticleScraper
#   end
#   
#   blog = BlogScraper.parse(html)
#   
#   blog.title  # => "Some page title"
#   blog.articles.first.link  # => "http://example.com"
#

require 'nokogiri'

class Scraper
  attr_reader :doc
  
  # Accepts string, open file, or Nokogiri document instance
  def initialize(doc)
    @doc = case doc
      when String, IO
        Nokogiri::HTML(doc)
      else
        doc
      end
    
    # initialize plural accessor values
    self.class.plurals.each { |name|
      send("#{name}=", [])
    }
  end
  
  # Initialize a new scraper and process data
  def self.parse(html)
    new(html).parse
  end
  
  # Specify a new singular scraping rule
  def self.element(selector)
    selector, name, klass = parse_rule_declaration(selector)
    rules << [selector, name, klass]
    attr_accessor name
    name
  end
  
  # Specify a new plural scraping rule
  def self.elements(selector)
    name = element(selector)
    plurals << name
  end
  
  # Let it do its thing!
  def parse
    self.class.rules.each do |selector, target, klass|
      if plural? target
        @doc.search(selector).each do |node|
          send(target) << parse_result(node, klass)
        end
      elsif node = @doc.at(selector)
        send("#{target}=", parse_result(node, klass))
      end
    end
    self
  end
  
  protected
  
  def parse_result(node, klass)
    klass ? klass.parse(node) : node.inner_text
  end
  
  def self.parse_rule_declaration(selector)
    if Hash === selector
      klass = selector.delete(:with)
      selector.to_a.flatten << klass
    else
      [selector.to_s, selector.to_sym, nil]
    end
  end
  
  def plural?(name)
    self.class.plurals.include?(name)
  end
  
  def self.rules
    @rules ||= []
  end
  
  def self.plurals
    @plurals ||= []
  end
end


## specs

if __FILE__ == $0
  require 'spec/autorun'
  
  class ArticleScraper < Scraper
    element 'h1' => :title
    element 'p.pubdate' => :published
    element 'a[@href]/@href' => :link
    
    def published_date
      @date ||= Date.parse published.sub('Published on ', '')
    end
  end

  class BlogScraper < Scraper
    element :title
    elements '#nav li' => :navigation_items
    elements 'div.hentry' => :articles, :with => ArticleScraper
  end
  
  describe BlogScraper do
    before(:all) do
      @blog = described_class.parse(DATA)
    end
    
    it "should have title" do
      @blog.title.should == 'Maximum awesome'
    end
    
    it "should have articles" do
      @blog.should have(2).articles
    end
    
    it "should have navigation items" do
      @blog.should have(3).navigation_items
      @blog.navigation_items.should == %w[Home About Help]
    end
    
    it "should have title, pubdate for first article" do
      article = @blog.articles[0]
      article.title.should == 'First article'
      article.published.should == 'Published on Oct 1'
      article.published_date.month.should == 10
      article.published_date.day.should == 1
      article.link.should be_nil
    end
    
    it "should have title, link for second article" do
      article = @blog.articles[1]
      article.title.should == 'Second article'
      article.published.should == 'Published on Sep 5'
      article.link.should == 'http://mislav.uniqpath.com'
    end
  end
end

__END__
<title>Maximum awesome</title>

<body>
  <ol id="nav">
    <li>Home</li>
    <li>About</li>
    <li>Help</li>
  </ol>
  
  <div class="hentry">
    <h1>First article</h1>
    <p class="pubdate">Published on Oct 1</p>
  </div>
  
  <div class="hentry">
    <h1>Second article</h1>
    <p class="pubdate">Published on Sep 5</p>
    <span><a href="http://mislav.uniqpath.com"></a></span>
  </div>
</body>
