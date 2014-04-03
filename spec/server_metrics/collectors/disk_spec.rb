require 'spec_helper'

describe ServerMetrics::Disk do
  let(:disk) { ServerMetrics::Disk.new }

  describe '#iostat' do
    it 'uses Disk#diskstats instead @disk_stats' do
      disk.should_receive(:disk_stats).and_return( [] )
      expect {
        disk.send(:iostat, '/dev/chunky')
      }.to_not raise_error
    end
  end

  describe '#disk_stats' do
    it 'returns lines from /proc/diskstats as array' do
      File.should_receive(:readlines).with('/proc/diskstats').
        and_return( %w(chunky bacon) )
      expect(disk.send(:disk_stats)).to eq %w(chunky bacon)
    end

    it 'returns empty array when /proc/diskstats is missing' do
      File.stub(:readlines).and_raise(Errno::ENOENT)
      expect(disk.send(:disk_stats)).to eq []
    end
  end
end
