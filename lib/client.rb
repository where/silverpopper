require 'builder'
require 'httparty'

class Silverpopper::Client
  include Silverpopper::Transact
  include Silverpopper::Silverpop
  include Silverpopper::Common

  attr_reader :user_name, :password, :pod
  def initialize(options={})
    @user_name = options['user_name']
    @password  = options['password']
    @pod       = options['pod'] || 5
  end

end
