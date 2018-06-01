# Tests for cms.rb

# Set sinatra environment to 'test'
ENV['RACK_ENV'] = 'test'

# Runs all tests
require 'minitest/autorun'
# rack testing library provides useful testing methods for requests and responses
require 'rack/test'
# Library providing several file utility methods for copying, moving, removing, etc.
require 'fileutils'
require 'pry'

require_relative '../cms.rb'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  ###########################################################################
  ############################### UTILITIES #################################
  ###########################################################################
  # required to work with rack/test methods
  def app
    Sinatra::Application
  end

  def setup
    # create test/data directory for isolated tests
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { "rack.session" => {user_name: 'admin'} }
  end

  ###########################################################################
  ################################# TESTS ###################################
  ###########################################################################
  def test_index_page_works
    create_document('about.md')
    create_document('changes.txt')
    
    get '/'
    
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response.headers['Content-Type'])
    assert_includes(last_response.body, 'about.md')
    assert_includes(last_response.body, 'changes.txt')
  end

  def test_view_text_file
    text = "Oh hi there!"
    create_document('hello.txt', text)

    get 'hello.txt'
    
    assert_equal(200, last_response.status)
    assert_equal('text/plain;charset=utf-8', last_response['Content-Type'])

    assert_equal("Oh hi there!", last_response.body)
  end

  def test_view_markdown_file
    text = "#Here's some markdown for ya!"
    create_document('about.md', text)

    get 'about.md'
    
    assert_equal(200, last_response.status)
    assert_equal('text/html;charset=utf-8', last_response['Content-Type'])
    rendered_html = "<h1>Here&#39;s some markdown for ya!</h1>"
    assert_includes(last_response.body, rendered_html)
  end

  #When a user attempts to view a document that does not exist, they should be redirected to the index page
  def test_document_not_found
    get '/file-that-does-not-exist'

    assert_equal(302, last_response.status) # assert that you're redirected
    assert_equal("The file 'file-that-does-not-exist' couldn't be found.", session[:error])
  end

  def test_edit_content
    create_document('markdown.md', '#Some content just to fill out')

    get '/markdown.md/edit', {}, admin_session

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, "<button type='submit'")
  end

  def test_updating_edited_content
    create_document('about.txt', 'Original content')
    
    post '/about.txt/save', {edited_text: 'New content'}, admin_session
    assert_equal(302, last_response.status)
    assert_includes('The file about.txt has been updated.', session[:success])

    get '/about.txt'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'New content')
  end

  def test_view_new_document_form
    get '/new', {}, admin_session

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'Add a new document')
    assert_includes(last_response.body, %q(<button type='submit'>Create))
  end

  def test_creating_new_document
    post '/new', {file_name: 'just_a_new_file.txt'}, admin_session
    assert_equal(302, last_response.status)
    assert_includes('just_a_new_file.txt was created', session[:success])
  end

  def test_create_new_document_without_file_name
    post '/new', {file_name: '    '}, admin_session

    assert_equal(422, last_response.status)
    assert_includes(last_response.body, 'A name is required')
    assert_includes(last_response.body, 'Add a new document')
  end

  def test_delete_document
    create_document('test_file.txt', 'Test input')
    
    post '/test_file.txt/destroy', {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("'test_file.txt' was deleted", session[:success])

    get last_response['Location']
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, %q(<a href="/test_file.txt">test_file.txt))
  end

  def test_not_logged_in
    get '/'

    assert_includes(last_response.body, 'Login')
  end

  def test_view_login_page
    get '/users/login'

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'Username:')
    assert_includes(last_response.body, 'Password:')
  end

  def test_logging_in_with_invalid_crentials
    # test with valid username and invalid password
    post '/users/login', {user_name: 'sandra', password: 'invalid_pass'}
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Invalid credentials")
    assert_includes(last_response.body, 'Username:')

    # test with invalid username and correct password
    post '/users/login', {user_name: 'invalid_username', password: 'secret'}
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Invalid credentials")
    assert_includes(last_response.body, 'Username:')
  end

  def test_logging_in_with_correct_credentials
    post '/users/login', {user_name: 'bob', password: 'apassword'}
    
    
    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:success])

    get last_response['Location']
    assert_includes(last_response.body, "Log Out")
    assert_includes(last_response.body, "Signed in as 'bob'")
  end

  def test_log_out
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as 'admin'"

    post "/users/logout"
    get last_response["Location"]

    assert_nil(session[:username])
    assert_includes(last_response.body, "You have been signed out")
    assert_includes(last_response.body, "Login")
  end

  def test_logged_out_user_cant_visit_edit_page
    create_document('about.txt', 'Some content')
    
    get '/about.txt/edit'
    assert_equal(302, last_response.status)
    assert_equal('You must be signed in to do that', session[:error])
  end
  
  def test_logged_out_user_cant_save_changes_to_document
    post '/some_file.txt/save', file_name: 'some_file.txt'
    assert_equal(302, last_response.status)
    assert_equal('You must be signed in to do that', session[:error])
  end

  def test_logged_out_users_cant_view_new_document_page
    get '/new'
    assert_equal(302, last_response.status)
    assert_equal('You must be signed in to do that', session[:error])
  end
  # Submit the new document form
  def test_logged_out_user_cant_create_new_files
    post 'new', file_name: 'some_file.txt'
    assert_equal(302, last_response.status)
    assert_equal('You must be signed in to do that', session[:error])
  end

  # Delete a document
  def test_logged_out_users_cant_delete_files
    create_document('file.txt', 'some content')

    post '/file.txt/destroy'
    assert_equal(302, last_response.status)
    assert_equal('You must be signed in to do that', session[:error]) 
  end
end