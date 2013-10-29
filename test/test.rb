require File.expand_path("test_helper", File.dirname(__FILE__))
class TestWithFixtures < Test::Unit::TestCase

  def test_system_info
    assert ServerMetrics::SystemInfo.architecture
    assert ServerMetrics::SystemInfo.os
    assert ServerMetrics::SystemInfo.os_version
    assert ServerMetrics::SystemInfo.num_processors
    assert ServerMetrics::SystemInfo.hostname
    assert ServerMetrics::SystemInfo.timezone
    assert ServerMetrics::SystemInfo.timezone_offset
  end

end