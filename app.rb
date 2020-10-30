require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'
require 'redcarpet'

ROOT ||= File.expand_path(__dir__).freeze

REXP = {
  folder: %r{(\/(?:.*\/)*)(?!.)},
  # 1 => relpath, starting with '/'
  file: %r((\/(?:.*\/)*)([^/]+\.([^/]+))(?!.)),
  # 1 => relpath,
  # 2 => filename w/ extension,
  # 3 => extension
}

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
get REXP[:folder] do |rel_path|
  begin
    path = validate_path(rel_path)
    @files = files_at_path(path)

    erb :index
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# Get a single file
get REXP[:file] do |rel_path, file_name, extension|
  begin
    file_path = validate_path(rel_path, file_name)
    content, type = file_content(file_path, extension)

    status 200
    content_type type
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

def file_content(file, extension)
  case extension
  when 'txt' then [read_plaintext(file), :txt]
  when 'md'  then [read_markdown(file), :html]
  else
    puts "Warning: unknown filetype #{extension}, #{file}"
    [read_plaintext(file), :txt]
  end
end

def read_plaintext(file_path)
  File.read(file_path)
end

def read_markdown(file_path)
  plaintext = read_plaintext file_path

  md_engine = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  html = md_engine.render(plaintext)

  erb(html)
end
