ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'tempfile'

require "./app"

class AppTest < Minitest::Test
  DATA_FOLDER = './test/data'
  FOLDER = 'nested_folder/'
  HTML_LI_FILE = '<a href="%{fn}">%{fn}</a>'
  HTML_EDIT_LINK = '(<a href="%{fn}/edit">edit</a>)'
  # ALLOWED_FILES = `ls #{DATA_FOLDER}`.split("\n")

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    get '/'
  end

  def teardown
    # {}`git checkout -- ./test/data`
  end

  def test_index_is_available
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_index_includes_files_in_data_folder
    data_files = Dir.entries(DATA_FOLDER)
    data_files.select! { |f| File.file?(DATA_FOLDER + f) }
    list_items = data_files.map { |fn| format(HTML_LI_FILE, fn: fn) }

    list_items.each do |line_item|
      assert_includes last_response.body, line_item
    end
  end

  def test_index_files_include_edit_links
    data_files = Dir.entries(DATA_FOLDER)
    data_files.select! { |f| File.file?(DATA_FOLDER + f) }
    edit_links = data_files.map { |fn| format(HTML_EDIT_LINK, fn: fn) }

    edit_links.each do |line_item|
      assert_includes last_response.body, line_item
    end
  end

  def test_index_includes_folders
    assert_includes last_response.body, format(HTML_LI_FILE, fn: FOLDER)
  end

  def test_index_doesnt_include_edit_links_for_folders
    refute_includes last_response.body, format(HTML_EDIT_LINK, fn: FOLDER)
  end

  def test_index_excludes_dot_links
    %w(. ..).each do |dot|
      dot_line = format(HTML_LI_FILE, fn: dot)
      refute_includes last_response.body, dot_line
    end
  end

  def test_nested_folders_do_include_dot_links
    get '/nested_folder/'

    %w(./ ../).each do |dot|
      dot_line = format(HTML_LI_FILE, fn: dot)
      assert_includes last_response.body, dot_line
    end
  end

  def test_get_favicon_returns_ok
    get '/favicon.ico'
    expected_content = File.open('./public/favicon.ico', 'rb', &:read)

    assert_equal 200, last_response.status
    assert_equal expected_content, last_response.body
  end

  def test_get_file_returns_ok
    get '/plain.txt'

    assert_equal 200, last_response.status
  end

  def test_get_text_file_yields_expected_content_type
    get '/plain.txt'

    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
  end

  def test_get_text_file_yields_expected_content
    get '/plain.txt'

    expected = File.read(DATA_FOLDER + '/plain.txt')
    assert_equal expected, last_response.body
  end

  def test_get_markdown_file_yields_expected_content_type
    get '/markdown.md'

    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end

  def test_get_markdown_file_yields_expected_content
    get '/markdown.md'

    refute_includes last_response.body, '# Here is a big heading'
    assert_includes last_response.body, '<h1>Here is a big heading</h1>'
  end

  def test_get_nonexistant_folder_redirects_to_index
    bad_folder_name = '/asdfasdfasasdf/'
    get bad_folder_name

    assert redirect?(last_response.status)
  end

  def test_get_nonexistant_folder_includes_error_message
    bad_folder_name = '/asdfasdfasasdf/'
    get bad_folder_name
    get last_response['Location']

    assert_includes last_response.body, "#{bad_folder_name} does not exist."
  end

  def test_get_nonexistant_file_redirects_to_index
    bad_file_name = '/asdfasdfasasdf.xyz'
    get bad_file_name

    assert redirect?(last_response.status)
  end

  def test_get_nonexistant_file_includes_error_message
    bad_file_name = '/asdfasdfasasdf.sdf'
    get bad_file_name
    get last_response['Location']

    assert_includes last_response.body, "#{bad_file_name} does not exist."
  end

  def test_flash_message_disappears_after_first_view
    bad_file_name = '/asdfasdfasasdf.sdf'
    get bad_file_name
    location = last_response['Location']
    2.times { get location }
    refute_includes last_response.body, "#{bad_file_name} does not exist."
  end

  def test_edit_page_includes_expected_content
    get '/markdown.md/edit'

    # includes filename
    assert_includes last_response.body, 'markdown.md'

    # includes text body
    assert_includes last_response.body, File.read('./test/data/markdown.md')
  end

  def test_edit_page_redirects_with_banner
    post '/plain.txt/edit', file_content: 'xyzzy'
    assert redirect?(last_response.status)

    get '/'
    assert_includes last_response.body, 'class="success"'
  end

  def test_edit_page_saves_content
    buffer = File.read('./test/data/plain.txt')
    begin
      post '/plain.txt/edit', file_content: 'xyzzy'
      get '/plain.txt'

      assert_equal 'xyzzy', last_response.body
    ensure
      File.write('./test/data/plain.txt', buffer)
    end
  end

  def test_new_document_page_renders_successfully
    get '/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input type="text"'
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_post_new_document_no_extension_doesnt_redirect
    post '/new', file_name: 'xyzzy'

    refute last_response.redirect?
    assert_includes last_response.body, '<input type="text"'
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_post_new_document_no_extension_includes_banner
    post '/new', file_name: 'xyzzy'

    assert_includes last_response.body, 'class="error"'
  end

  def test_post_new_document_incorrect_folder_redirects_to_index
    post 'xyzzy/new', file_name: 'xyzzy'

    assert last_response.redirect?
    assert_equal 'http://example.org/', last_response.location
  end

  def test_post_new_document_creates_file_successfully
    post '/new', file_name: 'xyzzy.txt'
    get '/'
    assert_includes last_response.body, 'class="success"'

    assert File.delete './test/data/xyzzy.txt'
  rescue StandardError
    assert false, 'file not created successfully'
  end

  def test_post_new_document_redirects_to_index
    post '/new', file_name: 'xyzzy.txt'

    assert last_response.redirect?
    assert_equal 'http://example.org/', last_response.location

    File.delete './test/data/xyzzy.txt'
  end
end

def redirect?(code)
  (300...400).cover? code
end
