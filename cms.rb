require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/contrib'
require 'redcarpet' # parser for markdown to html
require 'pry'
require 'yaml'
require 'bcrypt' # password hashing lib

configure do
  disable :logging # to not show double entries in terminal
  enable :sessions
  set :session_secret, 'what a secret'
  set :erb, :escape_html => true
end

FILE_EXTENSIONS = ['txt', 'md']

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

def join_or(arr)
  arr.clone.insert(-2, 'or').join(' ')
end

def extension_exist?(file_name)
  *base_name, extension = file_name.split('.')

  return false if base_name.size > 1
  
  FILE_EXTENSIONS.include?(extension)
end

def detect_file_name_error(file_name)
  file_name = file_name.strip

  case
  when file_name.empty?
    "A name is required"
  when !extension_exist?(file_name)
    "You must provide a file extension of "\
    "either: #{join_or(FILE_EXTENSIONS)} "\
    "Example: my_file_name.txt"
  end
end

def user_logged_in?
  session[:user_name]
end

def require_user_logged_in
  unless user_logged_in?
    session[:error] = "You must be signed in to do that"
    redirect '/'
  end
end

def load_user_credentials
  credentials_path = if ENV['RACK_ENV'] == 'test'
                      File.expand_path('../test/users.yaml' ,__FILE__)
                    else
                      File.expand_path('..//users.yaml' ,__FILE__)
                    end

  YAML.load_file(credentials_path)
end

def valid_password?(user_name, password)
  credentials = load_user_credentials
  
  if credentials.has_key?(user_name)
    bcrypt_pass = BCrypt::Password.new(credentials[user_name])
    bcrypt_pass == password
  else
    false
  end
end

#########################################
############### ROUTES ##################
#########################################
# Show all files
get '/' do
  # appends the wildcard operator to path
  pattern = File.join(data_path, '*')
  # returns an array with basenames of all files in /data
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

# View login page
get '/users/login' do
  erb :login, layout: :layout
end

# View the create new file form
get '/new' do
  require_user_logged_in
  
  erb :new_file, layout: :layout
end

# View file
get '/:file_name' do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  
  if File.exist?(file_path)
    load_file_content(file_name)
  else
    session[:error] = "The file '#{file_name}' couldn't be found."
    redirect '/'
  end
end

# Edit existing file
get '/:file_name/edit' do
  require_user_logged_in
  
  @file_name = params[:file_name]
  @file = File.read(File.join(data_path, @file_name))

  erb :edit_file, layout: :layout
end

# Update existing file
post '/:file_name/save' do 
  require_user_logged_in
  
  file_name = params[:file_name]
  edited_content = params[:edited_text]

  file_path = File.join(data_path, file_name)
  open(file_path, 'w') do |file|
    file.write(edited_content)
  end

  session[:success] = "The file #{file_name} has been updated."
  redirect '/'
end

# Create new file
post '/new' do
  require_user_logged_in
  
  file_name = params[:file_name]
  
  error = detect_file_name_error(file_name)
  if error
    session[:error] = error
    status 422
    erb :new_file, layout: :layout
  else
    File.open(File.join(data_path, file_name), 'w+')
    session[:success] = "#{file_name} was created"
    redirect '/'
  end
end

# Delete existing file
post '/:file_name/destroy' do
  require_user_logged_in
  
  file_name = params[:file_name]
  File.delete(File.join(data_path, file_name))

  session[:success] = "'#{file_name}' was deleted"
  redirect '/'
end

# Login user
post '/users/login' do
  @user_name = params[:user_name]
  @password = params[:password]

  # if credentials[@user_name] == @password
  if valid_password?(@user_name, @password)
    session[:user_name] = @user_name
    session[:success] = "Welcome!"
    redirect '/'
  else
    session[:error] = "Invalid credentials"
    erb :login, layout: :layout
  end
end

# Logout user
post '/users/logout' do
  session.clear
  session[:success] = "You have been signed out."
  redirect '/'
end