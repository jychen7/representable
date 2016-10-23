require 'representable/definition'

# Representable can be used in two ways.
#
# == On class level
#
# To try out Representable you might include the format module into the represented class directly and then
# define the properties.
#
#   class Hero < ActiveRecord::Base
#     include Representable::JSON
#     property :name
#
# This will give you to_/from_json for each instance. However, this approach limits your class to one representation.
#
# == On module level
#
# Modules give you much more flexibility since you can mix them into objects at runtime, roughly following the DCI
# pattern.
#
#   module HeroRepresenter
#     include Representable::JSON
#     property :name
#   end
#
#   hero.extend(HeroRepresenter).to_json
module Representable
  NORMAL_MODE  = 0
  EXCEPT_MODE  = 1
  INCLUDE_MODE = 2

  def self.included(base)
    base.class_eval do
      extend ClassMethods
      extend ClassMethods::Declarations
      extend ClassMethods::Accessors

      def self.included(base)
        base.representable_attrs.push(*representable_attrs) # "inherit".
        define_methods(representable_attrs, base)
      end

      # Copies the representable_attrs to the extended object.
      def self.extended(object)
        attrs = representable_attrs
        define_methods(representable_attrs, object.class)
        object.instance_eval do
          @representable_attrs = attrs
        end
      end
    end
  end

  # Reads values from +doc+ and sets properties accordingly.
  def update_properties_from(doc, options, format, &block)
    operation_mode, operation_hash = fetch_mode_from(options)
    representable_bindings_for(format).each do |bin|
      next if (operation_mode != NORMAL_MODE) && skip_property?(bin, operation_mode, operation_hash)

      value = bin.read(doc) || bin.definition.default
      send(bin.definition.setter, value)
    end
    self
  end

  private
  # Compiles the document going through all properties.
  def create_representation_with(doc, options, format, &block)
    operation_mode, operation_hash = fetch_mode_from(options)
    representable_bindings_for(format).each do |bin|
      next if (operation_mode != NORMAL_MODE) && skip_property?(bin, operation_mode, operation_hash)

      value = send(bin.definition.getter) || bin.definition.default
      bin_operation_hash = operation_hash[bin.definition.name.to_sym] || {}
      bin.write(doc, value, operation_mode, bin_operation_hash)
    end
    doc
  end

  # Checks and returns if the property should be included.
  def skip_property?(bin, operation_mode, operation_hash)
    # return unless props = options[:except] || options[:include]
    # res = props.include?(bin.definition.name.to_sym)
    # options[:include] ? !res : res
    exist_in_option_keys = operation_hash.keys.include?(bin.definition.name.to_sym)
    operation_mode == EXCEPT_MODE ? exist_in_option_keys : !exist_in_option_keys
  end

  def fetch_mode_from(options)
    # options = {include: [
    #   :name,
    #   {songs: [:name, :artist]}
    # ]}
    operation_mode = NORMAL_MODE
    operation_hash = {}
    if props = options[:except]
      operation_mode = EXCEPT_MODE
    elsif props = options[:include]
      operation_mode = INCLUDE_MODE
    end

    if props
      operation_hash = add_to_hash(operation_hash, props)
    end
    # operation_mode = INCLUDE_MODE
    # operation_hash = {
    #   name: nil,
    #   songs: {
    #     name: nil,
    #     artist: nil
    #   }
    # }
    [operation_mode, operation_hash]
  end

  def add_to_hash(operation_hash, props)
    case props.class.name
    when "Symbol"
      operation_hash[props] = {}
    when "Hash"
      props.each do |key, value|
        operation_hash[key] = {}
        operation_hash[key] = add_to_hash(operation_hash[key], value)
      end
    when "Array"
      props.each do |ele|
        operation_hash = add_to_hash(operation_hash, ele)
      end
    end
    operation_hash
  end

  def representable_attrs
    @representable_attrs ||= self.class.representable_attrs # DISCUSS: copy, or better not?
  end

  def representable_bindings_for(format)
    representable_attrs.map {|attr| format.binding_for_definition(attr) }
  end

  # Returns the wrapper for the representation. Mostly used in XML.
  def representation_wrap
    representable_attrs.wrap_for(self.class.name)
  end


  module ClassMethods # :nodoc:
    # Create and yield object and options. Called in .from_json and friends.
    def create_represented(document, *args)
      new.tap do |represented|
        yield represented, *args if block_given?
      end
    end

    def define_methods(representable_attrs, klass)
      return if !klass.respond_to?(:new)
      object = klass.new
      representable_attrs.each do |definition|
        if definition.name.to_s == "id"
          if !klass.ancestors.any? {|an| an.to_s ==  "ActiveRecord::Base" }
            klass.send :attr_accessor, :id
          end
        else
          if !object.respond_to?(definition.name)
            klass.send :attr_reader, definition.name
          end
          if !object.respond_to?("#{definition.name}=")
            klass.send :attr_writer, definition.name
          end
        end
      end
    end

    module Declarations
      def definition_class
        Definition
      end

      # Declares a represented document node, which is usually a XML tag or a JSON key.
      #
      # Examples:
      #
      #   property :name
      #   property :name, :from => :title
      #   property :name, :class => Name
      #   property :name, :default => "Mike"
      def property(name, options={})
        representable_attrs << definition_class.new(name, options)
      end

      # Declares a represented document node collection.
      #
      # Examples:
      #
      #   collection :products
      #   collection :products, :from => :item
      #   collection :products, :class => Product
      def collection(name, options={})
        options[:collection] = true
        property(name, options)
      end
    end


    module Accessors
      def representable_attrs
        @representable_attrs ||= Config.new
      end

      def representation_wrap=(name)
        representable_attrs.wrap = name
      end
    end
  end


  class Config < Array
    attr_accessor :wrap

    # Computes the wrap string or returns false.
    def wrap_for(name)
      return unless wrap
      return infer_name_for(name) if wrap === true
      wrap
    end

    private
    def infer_name_for(name)
      name.to_s.split('::').last.
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        downcase
    end
  end


  # Allows mapping formats to representer classes.
  # DISCUSS: this module might be removed soon.
  module Represents
    def represents(format, options)
      representer[format] = options[:with]
    end

    def representer
      @represents_map ||= {}
    end
  end
end
