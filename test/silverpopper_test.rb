require 'helper'

class SilverpoppperTest < Test::Unit::TestCase
  def test_initializer
    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 1)

    assert_equal 'testman', s.user_name
    assert_equal 'pass',    s.password
    assert_equal 1,         s.pod
  end

  def test_login
    s = Silverpopper.new(
      :user_name => 'testman',
      :password  => 'pass',
      :pod       => 5)

    s.login

  end

end
