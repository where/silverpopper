class Silverpopper
  attr_reader :user_name, :password, :pod
  def initialize(options={})
    @user_name = options[:user_name]
    @password  = options[:password]
    @pod       = options[:pod] || 5
  end



=begin
  def add_contact(options={})
    list_id    = options.delete(:list_id)
    auto_reply = options.delete(:auto_reply)

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

    doc = process_api_request(request_body)
    doc && doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['RecipientId'].text
  end

private

  def process_api_request(request_body)
  end
=end



  def login
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)
    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.Login{
          markup.USERNAME(@user_name)
          markup.PASSWORD(@password)
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)
    
    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase

      if success == 'true'
        session_id = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SESSIONID'].text
      end
    rescue
      throw "Invalid login xml response"
    end
    
    @session_id = ";jsessionid=#{session_id}"

    return success.downcase, session_id
  end

  def logout
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)
    markup.Envelope{
      markup.Body{
        markup.Logout
      }
    }
    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)

    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase

      return success
    rescue
      throw "Invalid logout xml response"
    end
  end

  def add_contact(contact_list_id, email, send_auto_reply, other)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.AddRecipient{
          markup.LIST_ID contact_list_id
          markup.CREATED_FROM "1"
          markup.SEND_AUTOREPLY "true" if send_auto_reply
          markup.COLUMN{
            markup.NAME 'EMAIL'
            markup.VALUE email
          }

          other.each { |field, value| markup.COLUMN{
              markup.NAME(field.to_s)
              markup.VALUE(value.to_s)
            }
          }
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)
    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase

      if success == 'true'
        recipient_id = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['RecipientId'].text
      end
    rescue
      throw "Invalid add_contact xml response"
    end
    
    return success, recipient_id
  end

  def select_contact(contact_list_id, email)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.SelectRecipientData{
          markup.LIST_ID contact_list_id
          markup.EMAIL email
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)
    success = successful?(doc)

    selected = success ? Hash.from_xml(ret_val.to_s)['Envelope']['Body']['RESULT'] : nil

    # Update Columns to be in reasonable format
    columns = selected['COLUMNS']['COLUMN'].inject(Hash.new) do |hash, value| 
      hash.merge({value['NAME'] => value['VALUE'] })
    end rescue nil
    selected['COLUMNS'] = columns if selected

    return success, selected
  end

  def update_contact(contact_list_id, email, fields)
    xml = String.new
    markup = Builder::XmlMarkup.new(:target => xml, :indent => 1)

    markup.instruct!
    markup.Envelope{
      markup.Body{
        markup.UpdateRecipient{
          markup.LIST_ID contact_list_id
          markup.OLD_EMAIL email

          fields.each do |field|
            markup.COLUMN {
              markup.NAME  field.first
              markup.VALUE field.second
            }
          end
        }
      }
    }

    ret_val = send_api_request(xml)
    doc = REXML::Document.new(ret_val)
    success = successful?(doc)

    selected = success ? Hash.from_xml(ret_val.to_s)['Envelope']['Body']['RESULT']['RecipientId'] : nil
    return success, selected
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
    #puts xml
    #return doc
    begin
      success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase
    rescue
      throw "Invalid add_contact xml response"
    end

    return success
  end

  def send_transact_mail(email, transaction_id, campaign_id, personalization)
    Assert.argument_is_of_type(Hash, personalization, 'personalization')
    
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

    #puts xml
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
    Assert.argument_is_string(markup)
    Assert.argument_is_string(url)

    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.request_uri)
    request.add_field "Content-Type", "text/xml;charset=UTF-8"
    request.body = markup

    return http.request(request).body
  end

  def send_api_request(markup)
    return send_request(markup, "http://api#{@pod}.silverpop.com/XMLAPI#{@session_id}")
  end

  def send_transact_request(markup)
    return send_request(markup, "http://transact#{@pod}.silverpop.com/XTMail#{@session_id}")
  end


  def successful?(doc)
    success = doc.elements['Envelope'].elements['Body'].elements['RESULT'].elements['SUCCESS'].text.downcase
    success == 'true'
  end


end
