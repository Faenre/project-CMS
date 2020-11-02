require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'
require 'redcarpet'

ROOT ||= File.expand_path(__dir__).freeze
PATH_EXPANSION = "#{ROOT}#{'/test' if test?}/data/%s"
SESSIONS ||= {}
LOGINS = { 'admin' => 'secret' }

REXP = {
  folder: %r{(\/(?:.*\/)*)(?!.)},
  new_file: %r((\/(?:.*\/)*)new(?!.)),
  # 1 => relpath, starting with '/'
  file: %r((\/(?:.*\/)*)([^/]+\.([^/]+))(?!.)),
  edit_file: %r((\/(?:.*\/)*)([^/]+\.([^/]+))\/edit(?!.)),
  delete_file: %r((\/(?:.*\/)*)([^/]+\.([^/]+))\/delete(?!.))
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
# GET   /               --> view index
# GET   /**/            --> view files in a folder
# GET   /**/*           --> view single file
# GET   /**/*/edit      --> view edit page for file
# POST  /**/*/edit      --> save page edits
# GET   /**/new         --> view page to create new file
# POST  /**/new         --> process file creation request
# POST  /**/*/delete    --> annihilate a file
# GET   /users/signin   --> view sign-in page
# POST  /users/signin   --> attempt login

before do
end

helpers do
  def file?(path, fname)
    File.file?(format(PATH_EXPANSION, path) + fname)
  end

  def flash?
    session[:error] || session[:success]
  end

  def rel_path_to(fname)
    "#{@path}#{fname}"
  end
end

get '/stylesheets/*' do |css|
  begin
    File.read("./public/#{css}")
  rescue Errno::ENOENT
    status 404
    ''
  end
end

get '/favicon.ico' do
  File.read '.public/favicon.ico'
end

get '/users/signin' do
  redirect '/' if signed_in?

  erb :signin
end

post '/users/signin' do
  user = params[:username]
  password = params[:password]
  if LOGINS[user]&.==(password)
    SESSIONS[user] ||= []
    SESSIONS[user] << session[:secret]
    session[:user] = user
    session[:success] = 'Logged in successfully!'
    redirect '/'
  else
    session[:error] = 'Invalid username or password.'
    erb :signin
  end
end

post '/users/signout' do
  require_login

  SESSIONS[user].delete session[:secret]
  session[:user] = nil
  session[:success] = 'Logged out successfully!'

  redirect '/'
end

# Render a list of files
get REXP[:folder] do |rel_path|
  begin
    @path = rel_path
    full_path = validate_path(rel_path)
    @files = files_at_path(full_path, rel_path != '/')

    erb :index
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# Render a single file
get REXP[:file] do |rel_path, file_name, extension|
  begin
    file_path = validate_path(rel_path, file_name)
    content, type = file_content(file_path, extension)

    status 200
    content_type type if type
    content
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    pass
  end
end

# Render the edit-file page
get REXP[:edit_file] do |rel_path, file_name, _|
  require_login
  begin
    file_path = validate_path(rel_path, file_name)
    @content, = file_content(file_path, 'txt')
    @path = rel_path + file_name
    @file_name = file_name

    erb :file_edit
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# Save changes to /some/file.txt/edit
post REXP[:edit_file] do |rel_path, file_name, _|
  require_login
  begin
    file_path = validate_path(rel_path, file_name)
    content = params['file_content']

    write_file file_path, content

    session[:success] = "#{file_name} saved successfully!"
    redirect '/'
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  end
end

# Render the 'new document' page
get REXP[:new_file] do |rel_path|
  require_login
  @path = rel_path
  @attempt = ''

  erb :file_new
end

# Create a new document
post REXP[:new_file] do |rel_path|
  require_login
  begin
    path = validate_path(rel_path)
    file = create_file(path, params['file_name'])

    session[:success] = "#{file} created successfully!"
    redirect rel_path
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    redirect '/'
  rescue ResourceAlreadyExistsError, NoExtensionError => e
    session[:error] = e.message
    @path = rel_path
    @attempt = params['file_name']
    erb :file_new
  end
end

# Delete a document
post REXP[:delete_file] do |rel_path, fname, _|
  require_login
  begin
    path = validate_path(rel_path, fname)

    File.delete(path)

    session[:success] = "#{fname} deleted successfully."
    status 200
    redirect '/'
  rescue ResourceDoesNotExistError => e
    session[:error] = e.message
    @path = rel_path
    erb :index
  end
end

# How did this happen??
not_found do
  session[:error] ||= 'Well, this is embarrassing...'
  redirect '/'
end

# ----

class ResourceDoesNotExistError < StandardError
end

class ResourceAlreadyExistsError < StandardError
end

class NoExtensionError < StandardError
end

def require_login
  return if signed_in?

  session[:error] = 'You must be signed in to continue.'
  redirect '/users/signin'
end

def signed_in?
  SESSIONS[user]&.include? session_id
end

def user; session[:user]; end

def session_id; session[:secret]; end

def files_at_path(path, include_dots = true)
  entries = Dir.entries(path)
  entries.shift 2 unless include_dots

  entries.map! do |entry|
    File.file?(path + entry) ? entry : entry + '/'
  end
end

def validate_path(rel_path, filename = '')
  path = format(PATH_EXPANSION, rel_path).squeeze '/'
  raise IndexError unless Dir.exist? path

  unless filename.empty?
    path += filename
    raise NameError unless File.exist? path
  end

  path
rescue IndexError, NameError
  raise ResourceDoesNotExistError, "#{rel_path + filename} does not exist."
end

def file_content(file, extension='txt')
  case extension
  when 'txt' then [read_plaintext(file), :txt]
  when 'md'  then [read_markdown(file), :html]
  when 'ico' then [read_image(file), nil]
  else
    puts "Warning: unknown filetype #{extension}, #{file}"
    [File.read(file), nil]
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

def read_image(file_path)
  File.open(file_path, 'rb', &:read)
end

def write_file(file_path, content)
  File.write(file_path, content)
end

def create_file(file_path, file_name)
  file_path_with_name = file_path + file_name

  if File.exist? file_path_with_name
    raise ResourceAlreadyExistsError, "#{file_path_with_name} already exists!"
  end

  unless %w(.txt .md).any? { |ext| file_name.include? ext }
    raise NoExtensionError, "Please add an extension."
  end

  File.open(file_path_with_name, 'w') {}
  file_name
end
