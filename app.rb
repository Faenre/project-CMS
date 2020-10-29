require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'

before do
end

helpers do
end

get '/' do
  @content = 'Getting started.'

  erb :index
end
