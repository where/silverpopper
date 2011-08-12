require 'helper'

class SilverpoppperTest < Test::Unit::TestCase
  def test_initializer
    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 1)

    assert_equal 'testman', s.user_name
    assert_equal 'pass',    s.password
    assert_equal 1,         s.pod
  end

  def test_login
    s = new_silverpop

    expect_login
    assert_equal "3631784201", s.login
  end


  def test_expect_malformed_login_response
    s = new_silverpop
    
    expect_send_request(login_request_xml, silverpop_url).
      returns(MockHTTPartyResponse.new(200, 
        "<Envelope><Body><RESULT></RESULT></Body></Envelope>"))

    assert_raise RuntimeError do
      s.login
    end
  end

  def test_logout
    s = new_silverpop

    expect_login
    expect_logout
    assert_equal "3631784201", s.login
    s.logout
    assert_nil s.instance_eval { @session_id }
  end

  def test_logout_failure
    s = new_silverpop

    expect_login
    expect_send_request(logout_request_xml, "#{silverpop_url};jsessionid=3631784201").returns(MockHTTPartyResponse.new(200, "<omg />"))
    
    s.login
    assert_raise RuntimeError do
      s.logout
    end

    assert_not_nil s.instance_eval { @session_id }
  end


  def test_add_contact
    s = new_silverpop

    expect_login
    expect_add_contact

    s.login
    s.add_contact("1", "testman@testman.com", false, {'Test Field' => 'Test Value'})
  end

  def test_add_contact_fails
    s = new_silverpop

    expect_login
    expect_send_request(add_contact_xml, silverpop_session_url).returns(MockHTTPartyResponse.new(200, "<omg />"))
    
    s.login

    assert_raise RuntimeError do
      s.add_contact("1", "testman@testman.com", false, {'Test Field' => 'Test Value'})    
    end
  end

  private
  
  def new_silverpop
    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 5)    
  end

  # use mocha to test api calls, this mimicks
  # how ActiveMerchant tests payment gateway
  # api calls

  def silverpop_url
    "http://api5.silverpop.com/XMLAPI"
  end

  def silverpop_session_url
    "#{silverpop_url};jsessionid=3631784201"
  end

  def expect_add_contact
    expect_send_request(add_contact_xml, silverpop_session_url).returns(MockHTTPartyResponse.new(200, "<Envelope>
<Body>
  <RESULT>
<SUCCESS>TRUE</SUCCESS>
<RecipientId>2007408974</RecipientId>
<ORGANIZATION_ID>322a4dd7-12ca943aa0c-c6f842ded9e6d11c5ffebd715e129037</ORGANIZATION_ID>
</RESULT>
 </Body>
</Envelope>
"))
  end

  def expect_logout
    expect_send_request(logout_request_xml, silverpop_session_url).returns(MockHTTPartyResponse.new(200, "<Envelope>\n<Body>\n  <RESULT>\n<SUCCESS>TRUE</SUCCESS>\n</RESULT>\n </Body>\n</Envelope>\n"))
  end

  def expect_login
    expect_send_request(login_request_xml, silverpop_url).returns(MockHTTPartyResponse.new(200, "<Envelope><Body><RESULT>
  <SUCCESS>true</SUCCESS>
  <SESSIONID>3631784201</SESSIONID>
  <ORGANIZATION_ID>322a4dc-c6f6d1ebd715e129037</ORGANIZATION_ID>
  <SESSION_ENCODING>;jsessionid=36ADDFB301</SESSION_ENCODING>
  </RESULT>
 </Body>
</Envelope>
")) 
  end

  def expect_send_request(markup, url)
    HTTParty.expects(:post).with(url, {:body => markup, :headers => {'Content-type' => 'text/xml;charset=UTF-8'}})
  end


  def login_request_xml
'<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
 <Body>
  <Login>
   <USERNAME>testman</USERNAME>
   <PASSWORD>pass</PASSWORD>
  </Login>
 </Body>
</Envelope>
'
  end

  def logout_request_xml
    "<Envelope>\n <Body>\n  <Logout/>\n </Body>\n</Envelope>\n"
  end

  def add_contact_xml
'<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
 <Body>
  <AddRecipient>
   <LIST_ID>1</LIST_ID>
   <CREATED_FROM>1</CREATED_FROM>
   <COLUMN>
    <NAME>EMAIL</NAME>
    <VALUE>testman@testman.com</VALUE>
   </COLUMN>
   <COLUMN>
    <NAME>Test Field</NAME>
    <VALUE>Test Value</VALUE>
   </COLUMN>
  </AddRecipient>
 </Body>
</Envelope>
'
  end

  class MockHTTPartyResponse
    attr_reader :code, :body
    def initialize(code, body)
      @code, @body = code, body
    end
  end

end
