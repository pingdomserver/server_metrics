require 'spec_helper'

describe ServerMetrics::Disk do
  let(:disk) { ServerMetrics::Disk.new }

  describe '#build_report' do
    it 'does not parse /proc/diskstats when on OS X' do
      disk.should_receive(:osx?).and_return(true)
      File.should_not_receive(:read).with('/proc/diskstats')
      expect(disk.run).to be
    end

    it 'parses /proc/diskstats when not on OS X' do
      disk.should_receive(:osx?).and_return(false)
      File.should_receive(:read).with('/proc/diskstats').and_return('')
      expect(disk.run).to be
    end
  end
end
