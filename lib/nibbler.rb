## A minimalistic, declarative HTML scraper

class Nibbler
  attr_reader :doc
  
  # Accepts string, open file, or Nokogiri-like document
  def initialize(doc)
    @doc = self.class.convert_document(doc)
    initialize_plural_accessors
  end
  
  # Initialize a new scraper and process data
  def self.parse(html)
    new(html).parse
  end
  
  # Specify a new singular scraping rule
  def self.element(*args, &block)
    selector, name, delegate = parse_rule_declaration(*args, &block)
    rules[name] = [selector, delegate]
    attr_accessor name
    name
  end
  
  # Specify a new plural scraping rule
  def self.elements(*args, &block)
    name = element(*args, &block)
    rules[name] << true
  end
  
  # Let it do its thing!
  def parse
    self.class.rules.each do |target, (selector, delegate, plural)|
      if plural
        @doc.search(selector).each do |node|
          send(target) << parse_result(node, delegate)
        end
      else
        send("#{target}=", parse_result(@doc.at(selector), delegate))
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
    end unless node.nil?
  end
  
  private
  
  def self.rules
    @rules ||= {}
  end
  
  def self.inherited(subclass)
    subclass.rules.update self.rules
  end
  
  # Rule declaration is in Hash or single argument form:
  # 
  #   { '//some/selector' => :name, :with => delegate }
  #     #=> ['//some/selector', :name, delegate]
  #   
  #   :title
  #     #=> ['title', :title, nil]
  def self.parse_rule_declaration(*args, &block)
    options, name = Hash === args.last ? args.pop : {}, args.first
    delegate = options.delete(:with)
    selector, property = name ? [name.to_s, name.to_sym] : options.to_a.flatten
    raise ArgumentError, "invalid rule declaration: #{args.inspect}" unless property
    # eval block in context of a new scraper subclass
    delegate = Class.new(delegate || Nibbler, &block) if block_given?
    return selector, property, delegate
  end
  
  def initialize_plural_accessors
    self.class.rules.each do |name, (s, k, plural)|
      send("#{name}=", []) if plural
    end
  end
  
  def self.convert_document(doc)
    unless doc.respond_to?(:at) && doc.respond_to?(:search)
      require 'nokogiri' unless defined? ::Nokogiri
      Nokogiri doc
    else
      doc
    end
  end
end


## specs

if __FILE__ == $0
  require 'spec/autorun'
  HTML = DATA.read
  
  class Article < Nibbler
    element 'h1' => :title
    element 'a/@href' => :link
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

  class BlogScraper < Nibbler
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
  
  class BlogWithArticlesBlock < BlogScraper
    elements 'div.hentry' => :articles do
      element 'h1' => :title
    end
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
    
    it "should override singular properties when re-parsing" do
      blog = @blog.dup
      blog.instance_variable_set('@doc', Nokogiri::HTML(''))
      blog.parse
      blog.title.should be_nil
      blog.should have(2).articles
    end
  end
  
  describe SpecialArticle do
    before(:all) do
      doc = Nokogiri::HTML(HTML).at('//div[2]')
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
  
  describe BlogWithArticlesBlock do
    before(:all) do
      @blog = described_class.parse(HTML)
    end
    
    it "should have article objects" do
      titles = @blog.articles.map { |article| article.title }
      titles.should == ['First article', 'Second article']
    end
  end
end

__END__
<!doctype html>
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
