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
    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 5)

    expect_login
    assert_equal "3631784201", s.login
  end


  def test_expect_malformed_login_response
    expect_send_request('<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
 <Body>
  <Login>
   <USERNAME>testman</USERNAME>
   <PASSWORD>pass</PASSWORD>
  </Login>
 </Body>
</Envelope>
', silverpop_url).returns(MockHTTPartyResponse.new(200, "<Envelope><Body><RESULT></RESULT></Body></Envelope>"))

    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 5)

    assert_raise RuntimeError do
      s.login
    end
  end

  private
  # use mocha to test api calls, this mimicks
  # how ActiveMerchant tests payment gateway
  # api calls

  def silverpop_url
    "http://api5.silverpop.com/XMLAPI"
  end

  def expect_login
    expect_send_request('<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
 <Body>
  <Login>
   <USERNAME>testman</USERNAME>
   <PASSWORD>pass</PASSWORD>
  </Login>
 </Body>
</Envelope>
', silverpop_url).returns(MockHTTPartyResponse.new(200, "<Envelope><Body><RESULT>
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

  class MockHTTPartyResponse
    attr_reader :code, :body
    def initialize(code, body)
      @code, @body = code, body
    end
  end

end
