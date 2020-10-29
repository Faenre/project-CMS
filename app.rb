require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'

ROOT ||= File.expand_path(__dir__).freeze

REXP_FOLDER ||= %r{/(.*/)*} # groups: 1 => relpath
REXP_FILE ||= %r{/(.*/)*([^/]+)} # groups: 1 => relpath, 2 => filename w/ ext

before do
end

helpers do
end

# Get a list of files
get REXP_FOLDER do |rel_path|
  rel_path ||= '/'

  @files = files_at_path(rel_path)

  erb :index
end

# Get a single file
get REXP_FILE do |rel_path, file_name|
  rel_path ||= '/'

  file_path = validate_path(rel_path)
  content = File.read(file_path + file_name)

  status 200
  content_type :txt
  content

  # status 200, { 'Content-Type': content_type }, content
end

def files_at_path(path, *kwargs)
  path.prepend ROOT + '/data'

  entries = Dir.entries(path)
  entries.shift 2 unless kwargs.include? :include_dots

  entries
end

def get_content_type(filename)
  extension = filename.split('.').last.to_sym
  known_types = { txt: 'text/plain' }

  known_types[extension] || 'text/plain'
end

# todo
def validate_path(path)
  ROOT + path + 'data/'
end

# todo
def out_of_bounds?(_path)
  # parents = path.count '..'
  false
end
