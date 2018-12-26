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
      "Filippos Vasilakis | #{current_page.data.title}"
    end
  end

  def base_url
    ENV['BASE_URL'] || "https://vasilakisfil.social"
  end

  def image_url(source)
    "#{base_url}#{image_path(source)}"
  end

  def current_url
    "#{base_url}#{current_page.url}"
  end
end
