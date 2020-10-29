require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'

ROOT ||= File.expand_path(__dir__).freeze

REXP_FOLDER ||= %r{(.*/)*} # groups: 1 => relpath
REXP_FILE ||= %r{/(.*/)*([^/]+)} # groups: 1 => relpath, 2 => filename w/ ext

configure do
  enable :sessions
  set :session_secret, 'this_isnt_very_secret'
  set :erb, escape_html: true
end

#
## Routes
#
# GET   /           -> view index
# GET   /**/        -> view files in a folder
# GET   /**/*       -> view single file
#

before do
end

helpers do
end

# Get a list of files
get REXP_FOLDER do |rel_path|
  begin
    rel_path ||= '/'

    path = validate_path(rel_path)
    @files = files_at_path(path)

    erb :index
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# Get a single file
get REXP_FILE do |rel_path, file_name|
  begin
    rel_path ||= '/'

    file_path = validate_path(rel_path, file_name)
    content = File.read(file_path)

    status 200
    content_type :txt
    content
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# How did this happen??
not_found do
  session[:error] = 'Well, this is embarrassing...'
  redirect '/'
end

# ----

class ResourceDoesNotExistError < StandardError
end

def files_at_path(path, **kwargs)
  entries = Dir.entries(path)
  entries.shift 2 unless kwargs[:include_dots]

  entries
end

def validate_path(rel_path, filename = '')
  path = "#{ROOT}/data/#{rel_path}".squeeze '/'
  raise IndexError unless Dir.exist? path

  unless filename.empty?
    path += filename
    raise NameError unless File.exist? path
  end

  path
rescue IndexError, NameError
  raise ResourceDoesNotExistError, "#{rel_path + filename} does not exist."
end
