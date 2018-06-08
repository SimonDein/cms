require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/contrib'
require 'redcarpet' # parser for markdown to html
require 'pry'
require 'yaml'
require 'bcrypt' # password hashing lib
require 'fileutils'

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

def credentials_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yaml' ,__FILE__)
  else
    File.expand_path('..//users.yaml' ,__FILE__)
  end
end

def load_user_credentials

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

def all_files
  # appends the wildcard operator to path
  pattern = File.join(data_path, '*')
  
  # returns an array with basenames of all files in /data
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def detect_sign_up_error(user_name, password)
  user_name = user_name.strip
  password = password.strip
  credentials = load_user_credentials

  case
  when user_name.empty?
    'A username is required'
  when credentials.has_key?(user_name)
    'Sorry - the username has already been taken'
  when password.empty?
    'A password is required'
  when password.size < 6
    'The password must consist of at least 6 characters (numbers, letters or symbols)'
  end
end

#########################################
############### ROUTES ##################
#########################################
# Show all files
get '/' do
  @files = all_files

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

# Sign up page
get '/users/sign_up' do
  erb :sign_up, layout: :layout
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

# Make a copy file from existing file
post '/:file_name/copy' do
  file_name, file_extension = params[:file_name].split('.')
  version = detect_version_number(file_name)

  new_file_name = file_name + '_copy.' + file_extension
  
  original_file_path = File.join(data_path, params[:file_name])
  copied_file_path = File.join(data_path,  new_file_name)

  FileUtils.copy_file(original_file_path, copied_file_path)
  session[:success] = "a copy of '#{file_name}' was created"
  redirect '/'
end

post '/users/sign_up' do
  user_name = params[:new_user_name]
  password =  params[:new_password]

  credentials = load_user_credentials

  error = detect_sign_up_error(user_name, password)
  if error
    session[:error] = error
    erb :sign_up, layout: :layout
  else
    encrypted_password = BCrypt::Password.create(password)
    credentials.store(user_name, encrypted_password)

    File.open(credentials_path, 'w') { |f| YAML.dump(credentials, f) }
    session[:success] = "You've successfully signed up.\nPlease login to proceed."
    redirect '/users/login'
  end
end