ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require "./app"

class AppTest < Minitest::Test
  HTML_LI_FILE = '<li><a href=%{fn}>%{fn}</a></li>'

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index_available
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_index_includes_files_in_data_folder
    get '/'

    data_files = Dir.entries('./data/')
    data_files.shift 2
    list_items = data_files.map { |fn| format(HTML_LI_FILE, fn: fn) }

    list_items.each do |line_item|
      assert_includes last_response.body, line_item
    end
  end

  def test_index_excludes_dot_links
    get '/'

    %w(. ..).each do |dot|
      dot_line = format(HTML_LI_FILE, fn: dot)
      refute_includes last_response.body, dot_line
    end
  end

  def test_get_file_returns_ok
    get '/history.txt'

    assert_equal 200, last_response.status
  end

  def test_get_file_yields_expected_content
    get '/history.txt'

    expected = File.read('./data/history.txt')
    assert_equal expected, last_response.body
  end

  def test_get_file_yields_expected_content_type
    get '/history.txt'

    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
  end
end
