# Provide an interface to the Transact API calls that Silverpop exposes
module Silverpopper::TransactApi
  # Send an email through the Transact API
  #
  # arguments are a hash, that expect string keys for: email, transaction_id, campaign_id.
  # any additional arguments are used as personalization arguments; hash key is 
  # the personalization tag name, hash value is the personalization value
  def send_transact_mail(options={})
    email          = options.delete('email')
    transaction_id = options.delete('transaction_id')
    campaign_id    = options.delete('campaign_id')

    request_body = String.new
    xml = Builder::XmlMarkup.new(:target => request_body, :indent => 1)

    xml.instruct!
    xml.XTMAILING{
      xml.CAMPAIGN_ID campaign_id
      xml.TRANSACTION_ID transaction_id
      xml.SEND_AS_BATCH 'false'
      xml.RECIPIENT{
        xml.EMAIL email
        xml.BODY_TYPE 'HTML'
        options.each do |key, value|
          xml.PERSONALIZATION{
            xml.TAG_NAME key
            xml.VALUE value
          }
        end
      }
    }

    doc = send_transact_request(request_body)
    validate_transact_success!(doc, "failure to send transact message")
    doc.elements['XTMAILING_RESPONSE'].elements['RECIPIENTS_RECEIVED'].text
  end

  protected

  # make transact api call, and parse the response with rexml
  def send_transact_request(markup)
    response = send_request(markup, 
      "#{@transact_url}/XTMail#{@session_id}")
    REXML::Document.new(response)
  end

  # raise message provided unless the passed response was successful
  def validate_transact_success!(document, message)
    unless transact_successful?(document)
      raise message
    end
  end

  # does the xml document indicate a transact successful response?
  def transact_successful?(doc)
    doc != nil &&
      doc.elements['XTMAILING_RESPONSE'] != nil &&
      doc.elements['XTMAILING_RESPONSE'].elements['ERROR_CODE'] != nil
  end
end
