$LOAD_PATH << File.expand_path( File.dirname(__FILE__) + '/..' )
require 'test/unit'
require 'lib/system_metrics'
require 'pry'
require 'awesome_print'
require 'timecop'
require 'mocha'
AwesomePrint.defaults = {
    :indent => -2,
    :sort_keys =>true
}


def fixtures(name)
  FixtureFile.new(File.expand_path(File.dirname(__FILE__)+"/fixtures/#{name}.txt"))
end

# parses fixture files, intended for easily mocking system calls
# Fixture files are in the format:
#
# ### `some shell command` options
# the text output ...
#
# ### `another command` options
#
# ... with options being whatever text you'd like to be able to select this command with later
class FixtureFile
  def initialize(file)
    contents=File.read(file)
    sections = contents.split(/### (.+)\n/)
    sections = sections[1..sections.size-1]
    @sections={}
    (0..sections.size-1).each do |index|
      @sections[sections[index]] = sections[index+1].chop if index.even?
    end
  end

  def command(cmd, options=nil)
    key = options ? @sections.keys.find{|k|k =~/`#{cmd}` #{options}/} : @sections.keys.find{|k|k =~/`#{cmd}`/}

    if !key
      puts "No fixture found for `#{cmd}` with options: #{options ? options : nil }. Fixtures available:\n"
      puts @sections.keys.join("\n")
      exit
    else
      @sections[key]
    end
  end
end