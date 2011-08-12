class Silverpopper

  def initialize(options={})
    @user_name = options[:user_name]
    @password  = options[:password]
    @pod       = options[:pod] || 5
  end

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

end
