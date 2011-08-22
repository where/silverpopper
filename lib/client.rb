require 'builder'
require 'httparty'

class Silverpopper::Client
  include Silverpopper::Transact
  include Silverpopper::Silverpop

  attr_reader :user_name, :password, :pod
  def initialize(options={})
    @user_name = options['user_name']
    @password  = options['password']
    @pod       = options['pod'] || 5
  end

  def login
    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)
    xml.instruct!
    xml.Envelope{
      xml.Body{
        xml.Login{
          xml.USERNAME(self.user_name)
          xml.PASSWORD(self.password)
        }
      }
    }

    doc = send_xml_api_request(request_body)
    validate_success!(doc, "Failure to login to silverpop") 
    self.session_id = result_dom(doc).elements['SESSIONID'].text
  end
  
  def logout
    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)
    xml.Envelope{
      xml.Body{
        xml.Logout
      }
    }

    doc = send_xml_api_request(request_body)
    validate_success!(doc, "Failure to logout of silverpop")
    self.session_id = nil
  end

  private

  def send_request(markup, url)
    resp = HTTParty.post(url, :body => markup, :headers => {'Content-type' => 'text/xml;charset=UTF-8'})
    raise "Request Failed" unless resp.code == 200 || resp.code == 201

    return resp.body
  end

  def session_id=(session_id)
    @session_id = session_id.blank? ? nil : ";jsessionid=#{session_id}"
    session_id
  end

  def validate_success!(document, message)
    unless successful?(document)
      raise message
    end
  end
end
