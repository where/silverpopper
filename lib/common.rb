module Silverpopper::Common

  def send_request(markup, url)
    resp = HTTParty.post(url, :body => markup, :headers => {'Content-type' => 'text/xml;charset=UTF-8'})
    raise "Request Failed" unless resp.code == 200 || resp.code == 201

    return resp.body
  end

end
