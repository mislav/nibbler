# DSL for defining data extraction rules from an abstract document object
module NibblerMethods
  def self.extended(base)
    base.send(:include, InstanceMethods) if base.is_a? Class
  end

  # Declare a singular scraping rule
  def element(*args, &block)
    selector, name, delegate = parse_rule_declaration(*args, &block)
    rules[name] = [selector, delegate]
    attr_accessor name
    name
  end

  # Declare a plural scraping rule
  def elements(*args, &block)
    name = element(*args, &block)
    rules[name] << true
  end

  # Parsing rules declared with `element` or `elements`
  def rules
    @rules ||= {}
  end

  # Process data by creating a new instance
  def parse(doc) new(doc).parse end

  private

  # Make subclasses inherit the parsing rules
  def inherited(subclass)
    super
    subclass.rules.update self.rules
  end

  # Rule declaration forms:
  #
  #   { 'selector' => :property, :with => delegate }
  #     #=> ['selector', :property, delegate]
  #
  #   :title
  #     #=> ['title', :title, nil]
  def parse_rule_declaration(*args, &block)
    options, name = Hash === args.last ? args.pop : {}, args.first
    delegate = options.delete(:with)
    selector, property = name ? [name.to_s, name.to_sym] : options.to_a.flatten
    raise ArgumentError, "invalid rule declaration: #{args.inspect}" unless property
    # eval block in context of a new scraper subclass
    delegate = Class.new(delegate || base_parser_class, &block) if block_given?
    return selector, property, delegate
  end

  def base_parser_class
    klass = self
    klass = klass.superclass until klass.superclass == Object
    klass
  end

  module InstanceMethods
    attr_reader :doc

    # Initialize the parser with a document
    def initialize(doc)
      @doc = doc
      # initialize plural properties
      self.class.rules.each { |name, (s, k, plural)| send("#{name}=", []) if plural }
    end

    # Parse the document and save values returned by selectors
    def parse
      self.class.rules.each do |target, (selector, delegate, plural)|
        if plural
          send(target).concat @doc.search(selector).map { |i| parse_result(i, delegate) }
        else
          send("#{target}=", parse_result(@doc.at(selector), delegate))
        end
      end
      self
    end

    # Dump the extracted data into a hash with symbolized keys
    def to_hash
      converter = lambda { |obj| obj.respond_to?(:to_hash) ? obj.to_hash : obj }
      self.class.rules.keys.inject({}) do |hash, name|
        value = send(name)
        hash[name.to_sym] = Array === value ? value.map(&converter) : converter[value]
        hash
      end
    end

    protected

    # `delegate` is optional, but should respond to `call` or `parse`
    def parse_result(node, delegate)
      if delegate
        method = delegate.is_a?(Proc) ? delegate : delegate.method(delegate.respond_to?(:call) ? :call : :parse)
        method.arity == 1 ? method[node] : method[node, self]
      else
        node
      end unless node.nil?
    end
  end
end

# An HTML/XML scraper
class Nibbler
  extend NibblerMethods

  # Parse data with Nokogiri unless it's already an acceptable document
  def initialize(doc)
    unless doc.respond_to?(:at) and doc.respond_to?(:search)
      require 'nokogiri' unless defined? ::Nokogiri
      doc = Nokogiri doc
    end
    super(doc)
  end

  protected

  def parse_result(node, delegate)
    if !delegate and node.respond_to? :inner_text
      node.inner_text
    else
      super
    end
  end
end

## specs

if __FILE__ == $0
  require 'date'
  require 'rspec/autorun'
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
    
    it "should convert to hash" do
      hash = @blog.to_hash
      hash[:navigation_items].should == %w[Home About Help]
      hash[:title].should == "Maximum awesome"
      article = hash[:articles].first
      article[:title] == "First article"
      article.key?(:link).should be_true
      article[:link].should be_nil
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
