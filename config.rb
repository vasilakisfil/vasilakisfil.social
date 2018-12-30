activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

activate :blog do |blog|
  # This will add a prefix to all links, template references and source paths
  blog.prefix = "blog"

  blog.permalink = "{year}/{month}/{day}/{title}.html"
  # Matcher for blog source files
  blog.sources = "posts/{year}/{month}-{day}-{title}/body.html"
  #blog.taglink = "blog/{tag}.html"
  #blog.layout = "layouts/blog/post"
  # blog.summary_separator = /(READMORE)/
  # using generator I can parse the post content and inject the breaking myself
  # it would allow me to inject a link instead of just a string
  #blog.summary_generator = ->(a, b, c, d){binding.pry && s}
  # blog.summary_length = 250
  # blog.year_link = "{year}.html"
  # blog.month_link = "{year}/{month}.html"
  # blog.day_link = "{year}/{month}/{day}.html"
  blog.default_extension = ".md"

  #blog.tag_template = "blog/tag.html"
  #blog.calendar_template = "blog/calendar.html"

  # Enable pagination
  blog.paginate = true
  blog.per_page = 10
  blog.page_link = "page/{num}"
end
activate :directory_indexes

page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page "/feed.xml", layout: false
page "/blog", layout: "blog/layout"
page "/blog/*", layout: "blog/post"

# Build-specific configuration
configure :build do
  activate :minify_css
  activate :minify_javascript
end

set :markdown_engine, :redcarpet
set(:markdown, {
  fenced_code_blocks: true,
  smartypants: true,
})

activate :sprockets
sprockets.append_path File.join(root, "node_modules")

activate :syntax, :line_numbers => false
activate :pry
require "helpers/custom_helpers"
helpers CustomHelpers
