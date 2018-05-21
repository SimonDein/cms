require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/contrib'
require 'redcarpet'

configure do
  # disable :logging # to not show double entries in terminal
  enable :sessions
  set :session_secret, 'what a secret'
  set :erb, :escape_html => true
end

#########################################
############## METHODS ##################
#########################################

def load_file_content(file_name)
  content = File.read('data/' + file_name)
  file_ext = file_name.split('.').last
  case file_ext
  when 'txt'
    headers['Content-Type'] = 'text/plain;charset=utf-8'
    content
  when 'md'
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end
  
end

def render_markdown(text)
  markdown_parser = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown_parser.render(text)
end

#########################################
############### ROUTES ##################
#########################################

before do
  @files = Dir.entries('data').reject { |file| File.directory?(file) }
end

get '/' do 
  erb :index, layout: :layout
end

get '/:file_name' do
  file_name = params[:file_name]

  if @files.none?(file_name)
    session[:error] = "The file '#{file_name}' couldn't be found"
    redirect '/'
  else
    load_file_content(file_name)
  end
end

get '/:file_name/edit' do
  @file_name = params[:file_name]
  @file = File.read('data/' + @file_name)

  erb :edit_file, layout: :layout
end

post '/:file_name/save' do
  edited_text = params[:edited_text]
  # TODO
  # edited_text should be saved to file
  # once saved
  # redirect to the index page
  # show success message of saved file
end