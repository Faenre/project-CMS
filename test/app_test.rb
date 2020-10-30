ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'tempfile'

require "./app"

class AppTest < Minitest::Test
  HTML_LI_FILE = '<a href="%{fn}">%{fn}</a>'
  HTML_EDIT_LINK = '(<a href="%{fn}/edit">edit</a>)'

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @dir = Dir.mktmpdir('temp_', './data')
    @dir_rel = @dir.delete_prefix './data'
    @dir_name = @dir.delete_prefix './data/'

    get '/'
  end

  def teardown
    FileUtils.remove_entry @dir
  end

  def test_index_available
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_index_includes_files_in_data_folder
    data_files = Dir.entries('./data/')
    data_files.shift 2
    list_items = data_files.map { |fn| format(HTML_LI_FILE, fn: fn) }

    list_items.each do |line_item|
      assert_includes last_response.body, line_item
    end
  end

  def test_index_files_include_edit_links
    data_files = Dir.entries('./data/')
    data_files.select! { |f| File.file? f }
    edit_links = data_files.map { |fn| format(HTML_EDIT_LINK, fn: fn) }

    edit_links.each do |line_item|
      assert_includes last_response.body, line_item
    end
  end

  def test_index_includes_folders
    assert_includes last_response.body, format(HTML_LI_FILE, fn: @dir_name)
  end

  def test_index_doesnt_include_edit_links_for_folders
    #
    refute_includes last_response.body, format(HTML_EDIT_LINK, fn: @dir_name)
  end

  def test_index_excludes_dot_links
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

  def test_get_text_file_yields_expected_content_type
    get '/history.txt'

    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
  end

  def test_get_markdown_file_yields_expected_content_type
    get '/about.md'

    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_get_folder_dne_redirects_to_index
    bad_folder_name = '/asdfasdfasasdf/'
    get bad_folder_name

    assert_equal 302, last_response.status
  end

  def test_get_folder_dne_includes_error_message
    bad_folder_name = '/asdfasdfasasdf/'
    get bad_folder_name
    get last_response['Location']

    assert_includes last_response.body, "#{bad_folder_name} does not exist."
  end

  def test_get_file_dne_redirects_to_index
    bad_file_name = '/asdfasdfasasdf.xyz'
    get bad_file_name

    assert_equal 302, last_response.status
  end

  def test_get_file_dne_includes_error_message
    bad_file_name = '/asdfasdfasasdf.sdf'
    get bad_file_name
    get last_response['Location']

    assert_includes last_response.body, "#{bad_file_name} does not exist."
  end

  def test_flash_message_disappears
    bad_file_name = '/asdfasdfasasdf.sdf'
    get bad_file_name
    location = last_response['Location']
    2.times { get location }
    refute_includes last_response.body, "#{bad_file_name} does not exist."
  end
end
