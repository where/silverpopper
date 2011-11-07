# The silverpop client to initialize and make XMLAPI or Transact API requests
# through.  Handles authentication, and many silverpop commands.
class Silverpopper::Client
  include Silverpopper::TransactApi
  include Silverpopper::XmlApi
  include Silverpopper::Common

  # user_name to log into silverpop with 
  attr_reader :user_name

  # pod to use, this should be a number and is used to build the url
  # to make api calls to
  attr_reader :pod

  # Initialize a Silverpopper Client
  #
  # expects a hash with string keys: 'user_name', 'password', 'pod'.  
  # pod argument is defaulted to 5
  def initialize(options={})
    @user_name = options['user_name']
    @password  = options['password']
    @pod       = options['pod'] || 5
      
    @api_url = defined?(SILVERPOP_API_URL) ? SILVERPOP_API_URL : "http://api#{@pod}.silverpop.com"
    @transact_url = defined?(SILVERPOP_TRANSACT_URL) ? SILVERPOP_TRANSACT_URL : "http://transact#{@pod}.silverpop.com"
  end

  protected
  # password to use to log into silverpop with
  attr_reader :password

end
