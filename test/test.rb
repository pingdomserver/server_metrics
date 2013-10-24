require File.expand_path("test_helper", File.dirname(__FILE__))
class TestWithFixtures < Test::Unit::TestCase

  def test_system_info
    assert Scout::SystemInfo.architecture
    assert Scout::SystemInfo.os
    assert Scout::SystemInfo.os_version
    assert Scout::SystemInfo.num_processors
    assert Scout::SystemInfo.hostname
    assert Scout::SystemInfo.timezone
    assert Scout::SystemInfo.timezone_offset
  end

end