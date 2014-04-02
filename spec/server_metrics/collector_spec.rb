require 'spec_helper'

describe ServerMetrics::Collector do
  let(:collector) { ServerMetrics::Collector.new }

  describe '#linux?' do
    it 'is true when target OS starts with linux' do
      collector.should_receive(:ruby_config).
        and_return( {'target_os' => 'linux42.0'} )
      expect(collector.linux?).to be true
    end

    it 'is false when target OS does not start with linux' do
      collector.should_receive(:ruby_config).
        and_return( {'target_os' => 'chunkybacon'} )
      expect(collector.linux?).to be false
    end
  end

  describe '#osx?' do
    it 'is true when target OS starts with darwin' do
      collector.should_receive(:ruby_config).
        and_return( {'target_os' => 'darwin42.0'} )
      expect(collector.osx?).to be true
    end

    it 'is false when target OS does not start with darwin' do
      collector.should_receive(:ruby_config).
        and_return( {'target_os' => 'chunkybacon'} )
      expect(collector.osx?).to be false
    end
  end
end
