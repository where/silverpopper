require 'builder'
require 'httparty'

class Silverpopper
  attr_reader :user_name, :password, :pod
  def initialize(options={})
    @user_name = options[:user_name]
    @password  = options[:password]
    @pod       = options[:pod] || 5
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

  def add_contact(options={})
    list_id    = options.delete('list_id')
    auto_reply = options.delete('auto_reply')

    request_body = ''
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)
    xml.instruct!
    xml.Envelope do
      xml.Body do
        xml.AddRecipient do
          xml.LIST_ID list_id
          xml.CREATED_FROM '1'
          xml.SEND_AUTOREPLY 'true' if auto_reply
          options.each do |field, value|
            xml.COLUMN do
              xml.NAME field.to_s
              xml.VALUE value.to_s
            end
          end
        end
      end
    end

    doc = send_xml_api_request(request_body)
    validate_success!(doc, "Failure to add contact")
    result_dom(doc).elements['RecipientId'].text rescue nil
  end

  def select_contact(options={})
    contact_list_id, email = options.delete('list_id'), options.delete('email')
    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)

    xml.instruct!
    xml.Envelope{
      xml.Body{
        xml.SelectRecipientData{
          xml.LIST_ID contact_list_id
          xml.EMAIL email
        }
      }
    }

    doc = send_xml_api_request(request_body)
    validate_success!(doc, "Failure to select contact")

    doc.elements['Envelope'].
      elements['Body'].
      elements['RESULT'].
      elements['COLUMNS'].collect do |i| 
        i.respond_to?(:elements) ?  [i.elements['NAME'].first, i.elements['VALUE'].first] : nil
      end.compact.inject(Hash.new) do |hash, value | 
        hash.merge({value[0].to_s => (value[1].blank? ? nil : value[1].to_s)}) 
    end
  end

  def update_contact(options={})
    contact_list_id = options.delete('list_id')
    email           = options.delete('email')

    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)

    xml.instruct!
    xml.Envelope{
      xml.Body{
        xml.UpdateRecipient{
          xml.LIST_ID contact_list_id
          xml.OLD_EMAIL email

          options.each do |field, value|
            xml.COLUMN {
              xml.NAME  field
              xml.VALUE value
            }
          end
        }
      }
    }

    doc = send_xml_api_request(request_body)
    validate_success!(doc, "Failure to update contact")
    result_dom(doc).elements['RecipientId'].text rescue nil
  end













  def send_mailing(email, mailing_id)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.SendMailing{
          markup.MailingId mailing_id
          markup.RecipientEmail email
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)

    #return doc
    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase
    rescue
      throw "Invalid add_contact xml response"
    end

    return success
  end

  def schedule_mailing(list_id, template_id, mailing_name, subject, from_name, from_address, reply_to, substitutions)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.ScheduleMailing{
          markup.TEMPLATE_ID template_id
          markup.LIST_ID list_id
          markup.SEND_HTML
          markup.SEND_TEXT
          markup.MAILING_NAME mailing_name
          markup.SUBJECT subject
          markup.FROM_NAME from_name if from_name != ''
          markup.FROM_ADDRESS from_address if from_address != ''
          markup.REPLY_TO reply_to if reply_to != ''
          if substitutions.length > 0
            markup.SUBSTITUTIONS{
              substitutions.each { |key, value|  
                markup.SUBSTITUTION{
                  markup.NAME key
                  markup.VALUE value
                }
              }
            }
          end
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)
    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase
    rescue
      throw "Invalid add_contact xml response"
    end

    return success
  end

  def send_transact_mail(email, transaction_id, campaign_id, personalization)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    # do not change the order of xml elements - Silverpop is very sensitive to order in context of Transact
    markup.instruct!
    markup.XTMAILING{
      markup.CAMPAIGN_ID campaign_id
      markup.TRANSACTION_ID transaction_id
      markup.SEND_AS_BATCH 'false'
      markup.RECIPIENT{
        markup.EMAIL email
        markup.BODY_TYPE 'HTML'
        personalization.each { |key, value|
          markup.PERSONALIZATION{
          markup.TAG_NAME key
          markup.VALUE value
          }
        }
      }
    }

    begin
      ret_val = send_transact_request(xml)
    rescue
      return -2, 'Internal error while processing http request'
    end

    doc = REXML::Document.new(ret_val)
    return -1 if doc == nil || doc.elements['XTMAILING_RESPONSE'] == nil || doc.elements['XTMAILING_RESPONSE'].elements['ERROR_CODE'] == nil
    return doc.elements['XTMAILING_RESPONSE'].elements['ERROR_CODE'].text, doc.elements['XTMAILING_RESPONSE'].elements['ERROR_STRING'].text
    
    #return ret_val
    #return doc
  end

  private

  def send_request(markup, url)
    resp = HTTParty.post(url, :body => markup, :headers => {'Content-type' => 'text/xml;charset=UTF-8'})
    raise "Request Failed" unless resp.code == 200 || resp.code == 201

    return resp.body
  end

  def send_api_request(markup)
    return send_request(markup, "http://api#{@pod}.silverpop.com/XMLAPI#{@session_id}")
  end

  def send_xml_api_request(markup)
    result = send_api_request(markup)
    REXML::Document.new(result)
  end

  def send_transact_request(markup)
    return send_request(markup, "http://transact#{@pod}.silverpop.com/XTMail#{@session_id}")
  end

  def successful?(doc)
    success = result_dom(doc).elements['SUCCESS'].text.downcase rescue 'false'
    success == 'true'
  end

  def result_dom(dom)
    dom.elements['Envelope'].elements['Body'].elements['RESULT']
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
