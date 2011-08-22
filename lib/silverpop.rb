module Silverpopper::Silverpop
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

    result_dom(doc).elements['COLUMNS'].collect do |i| 
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
    validate_success!(doc, "Failure to update contact")
    true
  end

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
    validate_success!(doc, "Failure to update contact")
    result_dom(doc).elements['MAILING_ID'].first.to_s
  end


  protected

  def successful?(doc)
    success = result_dom(doc).elements['SUCCESS'].text.downcase rescue 'false'
    success == 'true'
  end

  def result_dom(dom)
    dom.elements['Envelope'].elements['Body'].elements['RESULT']
  end
end
