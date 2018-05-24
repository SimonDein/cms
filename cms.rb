require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/contrib'
require 'redcarpet'
require 'pry'

configure do
  disable :logging # to not show double entries in terminal
  enable :sessions
  set :session_secret, 'what a secret'
  set :erb, :escape_html => true
end

#########################################
############## METHODS ##################
#########################################
def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def load_file_content(file_name)
  content = File.read(File.join(data_path, file_name))
  file_ext = file_name.split('.').last
  case file_ext
  when 'txt'
    headers['Content-Type'] = 'text/plain;charset=utf-8'
    content
  when 'md'
    erb render_markdown(content)
  end
end

def render_markdown(text)
  markdown_parser = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown_parser.render(text)
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

#########################################
############### ROUTES ##################
#########################################
get '/' do 
  # appends the wildcard operator to path
  pattern = File.join(data_path, '*')
  # returns an array with basenames of all files in /data
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  
  erb :index, layout: :layout
end

get '/:file_name' do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  
  if File.exist?(file_path)
    load_file_content(file_name)
  else
    session[:error] = "The file '#{file_name}' couldn't be found"
    redirect '/'
  end
end

get '/:file_name/edit' do
  @file_name = params[:file_name]
  @file = File.read(File.join(data_path, @file_name))

  erb :edit_file, layout: :layout
end

post '/:file_name/save' do
  file_name = params[:file_name]
  edited_content = params[:edited_text]

  file_path = File.join(data_path, file_name)
  open(file_path, 'w') do |file|
    file.write(edited_content)
  end

  session[:success] = "The file #{file_name} has been updated"
  redirect '/'
end