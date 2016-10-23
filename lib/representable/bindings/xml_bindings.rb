require 'representable/binding'

module Representable
  module XML
    class Binding < Representable::Binding
      def read(xml)
        value_from_node(xml)
      end
      
    private
      def xpath
        definition.from
      end

      def collect_for(xml)
        nodes = xml.search("./#{xpath}")
        vals  = nodes.collect { |node| yield node }
        
        definition.array? ? vals : vals.first
      end
    end
    
    
    # Represents a tag attribute.
    class AttributeBinding < Binding
      def write(xml, values, operation_mode=nil, operation_hash={})
        xml[definition.from] = values.to_s
      end

    private
      def value_from_node(xml)
        xml[definition.from]
      end
    end
    
    
    # Represents text content in a tag. # FIXME: is this tested???
    class TextBinding < Binding
      def write(xml, value, operation_mode=nil, operation_hash={})
        if definition.array?
          value.each do |v|
            add(xml, definition.from, v)
          end
        else
          add(xml, definition.from, value)
        end
      end

    private
      def value_from_node(xml)
        collect_for(xml) do |node| 
          node.content
        end
      end
      
      def add(xml, name, value)
        child = xml.add_child Nokogiri::XML::Node.new(name, xml.document)
        child.content = value
      end
    end
    

    # Represents a tag with object binding.
    class ObjectBinding < Binding
      include Representable::Binding::Hooks # includes #create_object and #write_object.
      include Representable::Binding::Extend
      
      # Adds the ref's markup to +xml+. 
      def write(xml, object, operation_mode=nil, operation_hash={})
        if definition.array?
          object.each do |item|
            write_entity(xml, item)
          end
        else
          write_entity(xml, object)
        end
      end

    private
      # Deserializes the ref's element from +xml+.
      def value_from_node(xml)
        collect_for(xml) do |node|
          create_object.from_node(node)
        end
      end
      
      def write_entity(xml, entity)
        xml.add_child(write_object(entity).to_node)
      end
    end
  end
end
