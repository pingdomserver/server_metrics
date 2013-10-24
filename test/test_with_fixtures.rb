require File.expand_path("test_helper",File.dirname(__FILE__))

class TestWithFixtures < Test::Unit::TestCase

  def test_cpu
    fixture = fixtures(:cpu)
    c = Scout::Cpu.new()

    Scout::Cpu::CpuStats.expects(:`).with("cat /proc/stat 2>&1").returns(fixture.command("cat /proc/stat 2>&1")).once
    c.expects(:`).with("uptime").returns(fixture.command("uptime")).once

    c.run
    assert c.data["Last minute"]
    assert c.data["Last five minutes"]
    assert c.data["Last fifteen minutes"]
    assert_equal 3, c.data.keys.size
    c
  end

  def test_cpu_second_run
    fixture = fixtures(:cpu)
    c = test_cpu

    Scout::Cpu::CpuStats.expects(:`).with("cat /proc/stat 2>&1").returns(fixture.command("cat /proc/stat 2>&1", "second run")).once
    c.expects(:`).with("uptime").returns(fixture.command("uptime")).once

    Timecop.travel(60) do
      c.run
    end

    assert c.data["IO wait"]
    assert c.data["Idle"]
  end


  # First run we get size info
  def test_disk
    c = Scout::Disk.new()
    fixture = fixtures(:disk)
    c.expects(:`).with("mount").returns(fixture.command("mount")).once
    c.expects(:`).with("df -h").returns(fixture.command("df -h")).once
    c.expects(:`).with("cat /proc/diskstats").returns(fixture.command("cat /proc/diskstats")).once
    c.run

    assert_equal ["/dev/xvda1"], c.data.keys
    res = c.data["/dev/xvda1"]

    assert res["Avail"]
    assert res["Filesystem"]
    assert res["Mounted on"]
    assert res["Size"]
    assert res["Use%"]
    assert res["Used"]
    assert_equal 6, res.keys.size
    c
  end

  # Second run we also get counter data
  def test_disk_second_run
    c=test_disk
    fixture = fixtures(:disk)
    c.expects(:`).with("mount").returns(fixture.command("mount")).once
    c.expects(:`).with("df -h").returns(fixture.command("df -h")).once
    c.expects(:`).with("cat /proc/diskstats").returns(fixture.command("cat /proc/diskstats", "ubuntu second run")).once

    Timecop.travel(60) do
      c.run
    end

    assert_equal ["/dev/xvda1"], c.data.keys
    res = c.data["/dev/xvda1"]
    assert res["WPS"]
    assert res["RPS"]
  end

  def test_memory
    fixture = fixtures(:memory)
    c = Scout::Memory.new()
    c.expects(:`).with("uname").returns("Linux").times(2)
    c.expects(:`).with("cat /proc/meminfo").returns(fixture.command("cat /proc/meminfo")).once
    c.run
    assert_equal 7, c.data.keys.size
    assert c.data['Swap total']
  end

  def test_network
    fixture = fixtures(:network)
    c = Scout::Network.new()
    c.expects(:`).with("cat /proc/net/dev").returns(fixture.command("cat /proc/net/dev")).once
    c.run

    c.expects(:`).with("cat /proc/net/dev").returns(fixture.command("cat /proc/net/dev", "second run")).once
    Timecop.travel(60) do
      c.run
    end

    assert c.data.keys.include?("eth0")
    assert c.data.keys.include?("eth1")
    assert_equal 2, c.data.keys.size

    assert c.data["eth0"]["Bytes in"]
    assert c.data["eth1"]["Bytes in"]
  end
end

