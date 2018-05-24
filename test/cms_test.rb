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
    text = "#Here's some markdown for ya!\n**This is bold**"
    create_document('about.md', text)

    get 'about.md'
    
    assert_equal(200, last_response.status)
    assert_equal('text/html;charset=utf-8', last_response['Content-Type'])
    rendered_html = "<h1>Here&#39;s some markdown for ya!</h1>\n\n<p><strong>This is bold</strong></p>\n"
    assert_equal(rendered_html, last_response.body)
  end

  #When a user attempts to view a document that does not exist, they should be redirected to the index page
  def test_document_not_found
    get '/file-that-does-not-exist'

    assert_equal(302, last_response.status) # assert that you're redirected
    follow_redirect!                        # follow redirect
    assert_equal(200, last_response.status) # assert that new page is delivered
    assert_includes(last_response.body, "The file 'file-that-does-not-exist' couldn't be found")
  end

  def test_edit_content
    create_document('markdown.md', '#Some content just to fill out')

    get '/markdown.md/edit'

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, "<button type='submit'")
  end

  def test_updating_edited_content
    create_document('about.txt', 'Original content')
    
    post '/about.txt/save', edited_text: 'New content'
    assert_equal(302, last_response.status)
    
    get last_response['Location']
    assert_includes(last_response.body, 'The file about.txt has been updated')

    get '/about.txt'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'New content')
  end
end