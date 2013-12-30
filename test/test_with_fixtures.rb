require File.expand_path("test_helper",File.dirname(__FILE__))

class TestWithFixtures < Test::Unit::TestCase

  def test_cpu
    fixture = fixtures(:cpu)
    c = ServerMetrics::Cpu.new()

    ServerMetrics::Cpu::CpuStats.expects(:`).with("cat /proc/stat 2>&1").returns(fixture.command("cat /proc/stat 2>&1")).once
    c.expects(:`).with("uptime").returns(fixture.command("uptime")).once

    c.run
    assert c.data[:last_minute]
    assert c.data[:last_five_minutes]
    assert c.data[:last_fifteen_minutes]
    assert_equal 3, c.data.keys.size
    c
  end

  def test_cpu_second_run
    fixture = fixtures(:cpu)
    c = test_cpu

    ServerMetrics::Cpu::CpuStats.expects(:`).with("cat /proc/stat 2>&1").returns(fixture.command("cat /proc/stat 2>&1", "second run")).once
    c.expects(:`).with("uptime").returns(fixture.command("uptime")).once

    Timecop.travel(60) do
      c.run
    end

    assert c.data[:io_wait]
    assert c.data[:idle]
  end

  # First run we get size info
  def test_disk
    ServerMetrics::Disk.any_instance.stubs("linux?").returns(true)
    c = ServerMetrics::Disk.new()
    fixture = fixtures(:disk)
    c.expects(:`).with("mount").returns(fixture.command("mount")).once
    c.expects(:`).with("df -Pkh").returns(fixture.command("df -Pkh")).once
    c.expects(:`).with("cat /proc/diskstats").returns(fixture.command("cat /proc/diskstats")).once
    c.run

    assert_equal ["/dev/xvda1"], c.data.keys
    
    res = c.data["/dev/xvda1"]

    assert res[:avail]
    assert res[:filesystem]
    assert res[:mounted_on]
    assert res[:size]
    assert res[:used_percent]
    assert res[:used]
    assert_equal 6, res.keys.size
    c
  end

  def test_disk_converts_use_percent_and_capacity_to_used_percent
    ServerMetrics::Disk.any_instance.stubs("linux?").returns(true)
    response_varieties = []
    response_varieties << <<-eos
Filesystem  Capacity
/dev/xvda1  70%
none        0%
none        0%
eos
    
    response_varieties << <<-eos
Filesystem  Use%
/dev/xvda1  70%
none        0%
none        0%
eos
    
    response_varieties<< <<-eos
Filesystem  %Use
/dev/xvda1  70%
none        0%
none        0%
eos
    
    fixture = fixtures(:disk)
    response_varieties.each do |response|
      c = ServerMetrics::Disk.new()
      c.expects(:`).with("mount").returns(fixture.command("mount")).once
      c.expects(:`).with("cat /proc/diskstats").returns(fixture.command("cat /proc/diskstats")).once
      c.expects(:`).with("df -Pkh").returns(response)
      c.run

      assert c.data['/dev/xvda1'][:used_percent]
    end
  end

  # Second run we also get counter data
  def test_disk_second_run
    c=test_disk
    fixture = fixtures(:disk)
    c.expects(:`).with("mount").returns(fixture.command("mount")).once
    c.expects(:`).with("df -Pkh").returns(fixture.command("df -Pkh")).once
    c.expects(:`).with("cat /proc/diskstats").returns(fixture.command("cat /proc/diskstats", "ubuntu second run")).once

    Timecop.travel(60) do
      c.run
    end

    assert_equal ["/dev/xvda1"], c.data.keys
    res = c.data["/dev/xvda1"]
    assert res[:wps]
    assert res[:rps]
    assert res[:rps_kb]
    assert res[:wps_kb]
  end

  def test_memory
    fixture = fixtures(:memory)
    c = ServerMetrics::Memory.new()
    c.expects(:`).with("uname").returns("Linux").times(2)
    c.expects(:`).with("cat /proc/meminfo").returns(fixture.command("cat /proc/meminfo")).once
    c.run
    assert_equal 7, c.data.keys.size
    # the field names should align with the disk field names
    assert c.data[:swap_size]
    assert c.data[:swap_used]
    assert c.data[:swap_used_percent]
    assert c.data[:used]
    assert c.data[:avail]
    assert c.data[:used_percent]
    assert c.data[:size]
  end

  def test_network
    ServerMetrics::Network.any_instance.stubs("linux?").returns(true)
    fixture = fixtures(:network)
    c = ServerMetrics::Network.new()
    c.expects(:`).with("cat /proc/net/dev").returns(fixture.command("cat /proc/net/dev")).once
    c.run

    c.expects(:`).with("cat /proc/net/dev").returns(fixture.command("cat /proc/net/dev", "second run")).once
    Timecop.travel(60) do
      c.run
    end

    assert c.data.keys.include?("eth0")
    assert c.data.keys.include?("eth1")
    assert_equal 2, c.data.keys.size

    assert c.data["eth0"][:bytes_in]
    assert c.data["eth1"][:bytes_in]
  end
end

