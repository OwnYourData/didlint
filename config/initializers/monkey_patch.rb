module CoreExtensions
    def deep_find(key, object=self, found=nil)
        if object.respond_to?(:key?) && object.key?(key)
            return object[key]
        elsif object.is_a? Enumerable
            object.find { |*a| found = deep_find(key, a.last) }
            return found
        end
    end
end