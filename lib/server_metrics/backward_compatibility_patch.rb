# Ruby 1.8.6 compatibility
if !String.method_defined?(:lines)
  class String
    def lines
      to_a
    end
  end
end 

# Ruby 1.8.6 compatibility
if !String.method_defined?(:start_with?)
  class String
    def start_with?(matcher)
      !!match(/\A#{matcher}/)
    end
  end
end
