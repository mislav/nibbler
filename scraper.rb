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

class Scraper
  attr_reader :doc
  
  # Accepts string, open file, or Nokogiri document instance
  def initialize(doc)
    @doc = case doc
      when String, IO
        require 'nokogiri' unless defined? ::Nokogiri
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
  
  # `klass` is optional, but should respond to `call` or `parse`
  def parse_result(node, klass)
    if klass
      klass.respond_to?(:call) ? klass.call(node) : klass.parse(node)
    elsif node.respond_to? :inner_text
      node.inner_text
    else
      node.to_s
    end
  end
  
  # Rule declaration is in Hash or single argument form:
  # 
  #   { '//some/selector' => :name, :with => MyClass }
  #     #=> ['//some/selector', :name, MyClass]
  #   
  #   :title
  #     #=> ['title', :title, nil]
  def self.parse_rule_declaration(selector)
    if Hash === selector
      klass = selector.delete(:with)
      selector.to_a.flatten << klass
    else
      [selector.to_s, selector.to_sym, nil]
    end
  end
  
  def self.rules
    @rules ||= []
  end
  
  def self.plurals
    @plurals ||= []
  end
  
  def plural?(name)
    self.class.plurals.include?(name)
  end
  
  def self.inherited(subclass)
    subclass.rules.concat self.rules
    subclass.plurals.concat self.plurals
  end
end


## specs

if __FILE__ == $0
  require 'spec/autorun'
  HTML = DATA.read
  
  class ArticleScraper < Scraper
    element 'h1' => :title
    element 'p.pubdate' => :published, :with => lambda { |node|
      node.inner_text.sub('Published on ', '')
    }
    element 'a[@href]/@href' => :link
    
    def published_date
      @date ||= Date.parse published
    end
  end

  class BlogScraper < Scraper
    element :title
    elements '#nav li' => :navigation_items
    elements 'div.hentry' => :articles, :with => ArticleScraper
  end
  
  class SpecialArticleScraper < ArticleScraper
    element 'span'
  end
  
  describe BlogScraper do
    before(:all) do
      @blog = described_class.parse(HTML)
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
      article.published.should == 'Oct 1'
      article.published_date.month.should == 10
      article.published_date.day.should == 1
      article.link.should be_nil
    end
    
    it "should have title, link for second article" do
      article = @blog.articles[1]
      article.title.should == 'Second article'
      article.published.should == 'Sep 5'
      article.link.should == 'http://mislav.uniqpath.com'
    end
  end
  
  describe SpecialArticleScraper do
    before(:all) do
      doc = Nokogiri::HTML(HTML).at('//div[position()=2]')
      @article = described_class.parse(doc)
      @parent_article = described_class.superclass.parse(doc)
    end
    
    it "should inherit title parsing from parent" do
      @article.title.should == 'Second article'
    end
    
    it "should have additional 'span' rule" do
      @article.span.should == 'My blog'
    end
    
    it "should not let superclass inherit rules" do
      @parent_article.should_not respond_to(:span)
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
    <span><a href="http://mislav.uniqpath.com">My blog</a></span>
  </div>
</body>
