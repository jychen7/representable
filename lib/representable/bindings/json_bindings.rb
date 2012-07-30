require 'representable/binding'

module Representable
  module JSON
    class Binding < Representable::Binding
    private
      def collect_for(hash)
        nodes = hash[definition.from] or return
        nodes = [nodes] unless nodes.is_a?(Array)

        vals  = nodes.collect { |node| yield node }

        definition.array? ? vals : vals.first
      end
    end

    # Represents plain key-value.
    class TextBinding < Binding
      def write(hash, value)
        hash[definition.from] = value
      end

      def read(hash)
        collect_for(hash) do |value|
          value
        end
      end
    end

    # Represents a tag with object binding.
    class ObjectBinding < Binding
      include Representable::Binding::Hooks # includes #create_object and #write_object.
      include Representable::Binding::Extend

      def write(hash, object)
        if definition.array?
          hash[definition.from] = object.collect { |obj| serialize(obj) }
        else
          hash[definition.from] = serialize(object)
        end
      end

      def read(hash)
        collect_for(hash) do |node|
          create_object.from_hash(node)
        end
      end

    private
      def serialize(object)
        return nil if object.nil?
        write_object(object).to_hash(:wrap => false)
      end
    end
  end
end
