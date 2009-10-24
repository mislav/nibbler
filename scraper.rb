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
    self.class.rules.each do |name, (s, k, plural)|
      send("#{name}=", []) if plural
    end
  end
  
  # Initialize a new scraper and process data
  def self.parse(html)
    new(html).parse
  end
  
  # Specify a new singular scraping rule
  def self.element(selector)
    selector, name, delegate = parse_rule_declaration(selector)
    rules[name] = [selector, delegate]
    attr_accessor name
    name
  end
  
  # Specify a new plural scraping rule
  def self.elements(selector)
    name = element(selector)
    rules[name] << true
  end
  
  # Let it do its thing!
  def parse
    self.class.rules.each do |target, (selector, delegate, plural)|
      if plural
        @doc.search(selector).each do |node|
          send(target) << parse_result(node, delegate)
        end
      elsif node = @doc.at(selector)
        send("#{target}=", parse_result(node, delegate))
      end
    end
    self
  end
  
  protected
  
  # `delegate` is optional, but should respond to `call` or `parse`
  def parse_result(node, delegate)
    if delegate
      delegate.respond_to?(:call) ? delegate.call(node) : delegate.parse(node)
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
      delegate = selector.delete(:with)
      selector.to_a.flatten << delegate
    else
      [selector.to_s, selector.to_sym, nil]
    end
  end
  
  def self.rules
    @rules ||= {}
  end
  
  def self.inherited(subclass)
    subclass.rules.update self.rules
  end
end


## specs

if __FILE__ == $0
  require 'spec/autorun'
  HTML = DATA.read
  
  class Article < Scraper
    element 'h1' => :title
    element 'a[@href]/@href' => :link
  end
  
  class TimestampedArticle < Article
    element 'p.pubdate' => :published, :with => lambda { |node|
      node.inner_text.sub('Published on ', '')
    }
    
    def published_date
      @date ||= Date.parse published
    end
  end
  
  class SpecialArticle < Article
    element 'span'
  end

  class BlogScraper < Scraper
    element :title
    elements '#nav li' => :navigation_items
  end
  
  class OverrideBlogScraper < BlogScraper
    elements :title
    element '#nav li' => :navigation_items
  end
  
  class BlogWithArticles < BlogScraper
    elements 'div.hentry' => :articles, :with => Article
  end
  
  class BlogWithTimestampedArticles < BlogScraper
    elements 'div.hentry' => :articles, :with => TimestampedArticle
  end
  
  class FakeHtmlParser
    def initialize(name)
      @name = name
    end
    
    def at(selector)
      "fake #{@name}"
    end
    
    def search(selector)
      (1..3).map { |n| self.class.new(@name + n.to_s) }
    end
  end
  
  describe BlogWithTimestampedArticles do
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
  
  describe SpecialArticle do
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
  
  describe BlogWithArticles, 'with fake HTML parser' do
    before(:all) do
      doc = FakeHtmlParser.new('test')
      @blog = described_class.parse(doc)
    end
    
    it "should have fake title" do
      @blog.title.should == 'fake test'
    end
    
    it "should have fake articles" do
      titles = @blog.articles.map { |a| a.title }
      titles.should == ['fake test1', 'fake test2', 'fake test3']
    end
  end
  
  describe OverrideBlogScraper do
    before(:all) do
      @blog = described_class.parse(HTML)
    end
    
    it "should have plural titles" do
      @blog.title.should == ['Maximum awesome']
    end
    
    it "should have singular navigation item" do
      @blog.navigation_items.should == 'Home'
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
