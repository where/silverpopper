require 'rubygems'
require 'bundler'
require 'fakeweb'
require 'mocha'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'silverpopper'

class Test::Unit::TestCase
end

FakeWeb.allow_net_connect = false
