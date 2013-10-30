require File.expand_path("test_helper",File.dirname(__FILE__))

class TestWithFixtures < Test::Unit::TestCase

  def test_colectors_defined
    assert_nothing_raised do
      ServerMetrics::Cpu
      ServerMetrics::Disk
      ServerMetrics::Memory
      ServerMetrics::Network
    end
  end

  def test_collector_to_hash
    c=ServerMetrics::Collector.new(:port=>80)
    h=c.to_hash
    assert h[:options]
    assert h[:data]
    assert h[:memory]
  end

  def test_collector_from_hash
    c=ServerMetrics::Collector.new(:port=>80)
    c2=ServerMetrics::Collector.from_hash(c.to_hash)
    assert_equal 80, c2.option(:port)
  end

  def test_collector
    c=SomeCollector.new
    c.run
    assert_equal({:capacity=>9}, c.data)
  end

  def test_collector_with_memory
    c=SomeCollectorWithMemory.new
    c.run
    assert_equal(0, c.data["val"])
    c.run
    assert_equal(1, c.data["val"])
  end

  def test_collector_with_counter
    c=SomeCollectorWithCounter.new
    c.run
    assert_equal(nil, c.data["val"])
    Timecop.travel(1) do
      c.run
      assert_includes(450..550, c.data["val"])
    end
  end


  def test_multi_collector
    c=SomeMultiCollector.new
    c.run
    assert_equal({:alpha=>{"capacity"=>9},:beta=>{"capacity"=>10}}, c.data)
  end

  def test_multi_collector_with_memory
    c=SomeMultiCollectorWithMemory.new
    c.run
    assert_equal(0, c.data[:alpha]["val"])
    assert_equal(100, c.data[:beta]["val"])
    c.run
    assert_equal(1, c.data[:alpha]["val"])
    assert_equal(101, c.data[:beta]["val"])
  end

  def test_multi_collector_with_counter
    c=SomeMultiCollectorWithCounter.new
    c.run
    assert_equal(nil, c.data[:alpha])
    assert_equal(nil, c.data[:beta])
    Timecop.travel(1) do
      c.run
      assert_include(450..550, c.data[:alpha]["val"])
      assert_include(950..1050, c.data[:beta]["val"])
    end
  end

  def test_processes_to_hash
    p = ServerMetrics::Processes.new
    last_run=Time.now-60
    p.instance_variable_set '@last_run', last_run
    p.instance_variable_set '@last_process_list', "bogus value"

    assert_equal({:last_run=>last_run,:last_process_list=>"bogus value"}, p.to_hash)
  end

  def test_processes_from_hash
    last_run=Time.now-60
    p=ServerMetrics::Processes.from_hash(:last_run=>last_run,:last_process_list=>"bogus value")
    assert_equal last_run, p.instance_variable_get("@last_run")
    assert_equal "bogus value", p.instance_variable_get("@last_process_list")
  end

  # Helper Classes
  class SomeCollector < ServerMetrics::Collector
    def build_report
      report(:capacity=>9)
    end
  end

  class SomeMultiCollector < ServerMetrics::MultiCollector
    def build_report
      report(:alpha,"capacity"=>9)
      report(:beta,"capacity"=>10)
    end
  end

  class SomeCollectorWithMemory < ServerMetrics::Collector
    def build_report
      @val = memory(:val) || 0
      report("val"=>@val)
      remember :val=>@val+1
    end
  end

  class SomeMultiCollectorWithMemory < ServerMetrics::MultiCollector
    def build_report
      @alpha_val = memory(:alpha,:val) || 0
      @beta_val = memory(:beta,:val) || 100

      report(:alpha, "val"=>@alpha_val)
      report(:beta, "val"=>@beta_val)

      remember(:alpha, :val => @alpha_val+1)
      remember(:beta,  :val => @beta_val+1)
    end
  end

  class SomeCollectorWithCounter < ServerMetrics::Collector
    def build_report
      @val = memory(:val) || 0
      counter "val", @val, :per=>:second
      remember :val=>@val+500
    end
  end

  class SomeMultiCollectorWithCounter < ServerMetrics::MultiCollector
    def build_report
      @alpha_val = memory(:alpha,:val) || 0
      @beta_val = memory(:beta,:val) || 0

      counter(:alpha, "val", @alpha_val, :per=>:second)
      counter(:beta, "val", @beta_val, :per=>:second)

      remember(:alpha, :val => @alpha_val+500)
      remember(:beta,  :val => @beta_val+1000)
    end
  end

end