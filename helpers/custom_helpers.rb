module CustomHelpers
  def index?
    current_page.url == "/"
  end

  def blog_index?
    current_page.url == "/blog" || current_page.url == "/blog/"
  end

  def page_title
    if index?
      "Filippos Vasilakis"
    else
      "Filippos Vasilakis | #{current_page.path.gsub(".html","")}"
    end
  end

  def foobar(test)
    binding.pry
  end
end
