module CustomHelpers
  def index?
    current_page.url == "/"
  end
end
