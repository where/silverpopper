# Provide an interface for the Silverpop XMLAPI to
# do basic interactions with the lead.
module Silverpopper::XmlApi

  # Authenticate through the xml api
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
    validate_silverpop_success!(doc, "Failure to login to silverpop") 
    self.session_id = result_dom(doc).elements['SESSIONID'].text
  end
  
  # Expire the Session Id and forget the stored Session Id
  def logout
    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)
    xml.Envelope{
      xml.Body{
        xml.Logout
      }
    }

    doc = send_xml_api_request(request_body)
    validate_silverpop_success!(doc, "Failure to logout of silverpop")
    self.session_id = nil
  end

  # Insert a lead into silverpop
  #
  # expects a hash containing the strings: list_id, email and optionally
  # the string auto_reply.  any entries in the hash will be used to
  # populate the column name and values of the lead.
  # Returns the recipient id if successfully added, raises on error.
  def add_contact(options={})
    list_id    = options.delete('list_id')
    email      = options.delete('email')
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

          xml.COLUMN do
            xml.NAME 'EMAIL'
            xml.VALUE email
          end

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
    validate_silverpop_success!(doc, "Failure to add contact")
    result_dom(doc).elements['RecipientId'].text rescue nil
  end

  # Remove the contact from a list.
  #
  # expects a hash containing the strings: list_id and email.
  # Any additional columns passed will be treated as 'COLUMNS',
  # these COLUMNS are used in the case there is not a primary
  # key on email, and generally will not be used.
  def remove_contact(options={})
    list_id    = options.delete('list_id')
    email      = options.delete('email')

    request_body = ''
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)
    xml.instruct!
    xml.Envelope do
      xml.Body do
        xml.RemoveRecipient do
          xml.LIST_ID list_id
          xml.EMAIL   email unless email.nil?
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
    validate_silverpop_success!(doc, "Failure to remove contact")
    true
  end

  # Request details for lead.  
  #
  # expects a hash that contains the strings:
  # list_id, email.  Returns a hash containing properties
  # (columns) of the lead.
  def select_contact(options={})
    contact_list_id = options.delete('list_id')
    email           = options.delete('email')
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
    validate_silverpop_success!(doc, "Failure to select contact")

    result_dom(doc).elements['COLUMNS'].collect do |i| 
        i.respond_to?(:elements) ?  [i.elements['NAME'].first, i.elements['VALUE'].first] : nil
      end.compact.inject(Hash.new) do |hash, value | 
        hash.merge({value[0].to_s => (value[1].blank? ? nil : value[1].to_s)}) 
    end
  end

  # Update the column values of a lead in silverpop.
  #
  # expects a hash that contains the string: list_id, email.  
  # additional values in the hash will be passed as column values, 
  # with the key being the column name, and the value being the value.
  # Returns the Recipient Id.
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
    validate_silverpop_success!(doc, "Failure to update contact")
    result_dom(doc).elements['RecipientId'].text rescue nil
  end

  # Send an email to a user with a pre existing template.  
  #
  # expects a hash containing the strings: email, mailing_id.  
  def send_mailing(options={})
    email, mailing_id = options.delete('email'), options.delete('mailing_id')
    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)

    xml.instruct!
    xml.Envelope{
      xml.Body{
        xml.SendMailing{
          xml.MailingId mailing_id
          xml.RecipientEmail email
        }
      }
    }

    doc = send_xml_api_request(request_body)
    validate_silverpop_success!(doc, "Failure to update contact")
    true
  end

  # Schedule a mailing to be sent to an entire list. 
  # expects a hash containing the keys with the strings: 
  # list_id, template_id, mailing_name, subject, from_name, 
  # from_address, reply_to.  Additional entries in the argument 
  # will be treated as the substitution name, and substitution values.
  # Returns the Mailing Id.
  def schedule_mailing(options={})
    list_id      = options.delete('list_id')
    template_id  = options.delete('template_id')
    mailing_name = options.delete('mailing_name')
    subject      = options.delete('subject')
    from_name    = options.delete('from_name')
    from_address = options.delete('from_address')
    reply_to     = options.delete('reply_to')

    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)

    xml.instruct!
    xml.Envelope{
      xml.Body{
        xml.ScheduleMailing{
          xml.TEMPLATE_ID template_id
          xml.LIST_ID list_id
          xml.SEND_HTML
          xml.SEND_TEXT
          xml.MAILING_NAME mailing_name
          xml.SUBJECT subject
          xml.FROM_NAME from_name if from_name != ''
          xml.FROM_ADDRESS from_address if from_address != ''
          xml.REPLY_TO reply_to if reply_to != ''
          if options.length > 0
            xml.SUBSTITUTIONS{
              options.each { |key, value|  
                xml.SUBSTITUTION{
                  xml.NAME key
                  xml.VALUE value
                }
              }
            }
          end
        }
      }
    }
    
    doc = send_xml_api_request(request_body)
    validate_silverpop_success!(doc, "Failure to update contact")
    result_dom(doc).elements['MAILING_ID'].first.to_s
  end

  protected

  # Given a silverpop api response document, was the api call successful?
  def silverpop_successful?(doc)
    success = result_dom(doc).elements['SUCCESS'].text.downcase rescue 'false'
    success == 'true'
  end

  # Given a silverpop api response document, parse out the result
  def result_dom(dom)
    dom.elements['Envelope'].elements['Body'].elements['RESULT']
  end

  # Execute an xml api request, and parse the response
  def send_xml_api_request(markup)
    result = send_request(markup, "http://api#{@pod}.silverpop.com/XMLAPI#{@session_id}")
    REXML::Document.new(result)
  end

  # Given a parsed xml response document for the silverpop api call
  # raise the given message unless the call was successful
  def validate_silverpop_success!(document, message)
    unless silverpop_successful?(document)
      raise message
    end
  end

  # A helper method for setting the session_id when logging in
  def session_id=(session_id)
    @session_id = session_id.blank? ? nil : ";jsessionid=#{session_id}"
    session_id
  end
end
