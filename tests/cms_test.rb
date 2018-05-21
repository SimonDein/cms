# Tests for cms.rb

# Set sinatra environment to 'test'
ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms.rb'

class CMSTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def test_index_page_works
    get '/'
    
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response.headers['Content-Type'])
  end

  def test_index_page_contains_all_content
    get '/'
    
    assert_includes(last_response.body, "about.txt")
    assert_includes(last_response.body, "facts.txt")
    assert_includes(last_response.body, "ruby_releases.txt")
    assert_includes(last_response.body, "the_history_of_titanic.txt")
  end

  def test_content_pages_work
    content_page = ['about.txt', 'facts.txt',
      'ruby_releases.txt', 'the_history_of_titanic.txt'].sample
    
    get "/#{content_page}"

    assert_equal(200, last_response.status)
    assert_equal('text/plain;charset=utf-8', last_response['Content-Type'])
  end

  def test_content_pages_contains_all_file_content
    content = ['about.txt', 'facts.txt',
              'ruby_releases.txt', 'the_history_of_titanic.txt'].sample
    
    get "/#{content}"
    
    content = File.read("data/#{content}")
    assert_equal(content, last_response.body)
  end

  #When a user attempts to view a document that does not exist, they should be redirected to the index page
  def test_non_existant_document_redirects_to_index_and_displays_error
    get '/file-that-does-not-exist'

    assert_equal(302, last_response.status) # assert that you're redirected
    follow_redirect!                        # follow redirect
    assert_equal(200, last_response.status) # assert that new page is delivered
    assert_includes(last_response.body, "The file 'file-that-does-not-exist' couldn't be found")
  end

  def test_markdown_files_are_parsed
    get '/markdown.md'

    text = "<h3>Hey! It&#39;s me:</h3>\n\n<h1>Markdown</h1>\n\n<p>Markdown has a "\
    "<em>specific</em> syntax that can be <strong>rendered</strong> to html.\n"\
    "<strong>pretty</strong> cool if you ask <em>me</em>.</p>\n"
    assert_equal(200, last_response.status)
    assert_equal('text/html;charset=utf-8', last_response['Content-Type'])
    assert_equal(text, last_response.body)
  end
end