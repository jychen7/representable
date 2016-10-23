require 'test_helper'
require 'representable/json'
require 'representable/xml'

class RepresentableTest < MiniTest::Spec
  class Band
    include Representable
    property :name
    attr_accessor :name
  end

  class PunkBand < Band
    property :street_cred
    attr_accessor :street_cred
  end

  module BandRepresentation
    include Representable

    property :name
  end

  module PunkBandRepresentation
    include Representable
    include BandRepresentation

    property :street_cred
  end


  describe "#representable_attrs" do
    it "responds to #representable_attrs" do
      assert_equal 1, Band.representable_attrs.size
      assert_equal "name", Band.representable_attrs.first.name
    end

    describe "in module" do
      it "returns definitions" do
        assert_equal 1, BandRepresentation.representable_attrs.size
        assert_equal "name", BandRepresentation.representable_attrs.first.name
      end

      it "inherits to including modules" do
        assert_equal 2,  PunkBandRepresentation.representable_attrs.size
        assert_equal "name", PunkBandRepresentation.representable_attrs.first.name
        assert_equal "street_cred", PunkBandRepresentation.representable_attrs.last.name
      end

      it "inherits to including class" do
        band = Class.new do
          include Representable
          include PunkBandRepresentation
        end

        assert_equal 2,  band.representable_attrs.size
        assert_equal "name", band.representable_attrs.first.name
        assert_equal "street_cred", band.representable_attrs.last.name
      end

      it "allows including the concrete representer module later" do
        require 'representable/json'
        vd = class VD
          attr_accessor :name, :street_cred
          include Representable::JSON
          include PunkBandRepresentation
        end.new
        vd.name        = "Vention Dention"
        vd.street_cred = 1
        assert_equal "{\"name\":\"Vention Dention\",\"street_cred\":1}", vd.to_json
      end

      #it "allows including the concrete representer module only" do
      #  require 'representable/json'
      #  module RockBandRepresentation
      #    include Representable::JSON
      #    property :name
      #  end
      #  vd = class VH
      #    include RockBandRepresentation
      #  end.new
      #  vd.name        = "Van Halen"
      #  assert_equal "{\"name\":\"Van Halen\"}", vd.to_json
      #end
    end
  end


  describe "Representable" do
    it "allows mixing in multiple representers" do
      class Bodyjar
        include Representable::XML
        include Representable::JSON
        include PunkBandRepresentation

        self.representation_wrap = "band"
        attr_accessor :name, :street_cred
      end

      band = Bodyjar.new
      band.name = "Bodyjar"
      band.street_cred = 1
      assert_equal "{\"band\":{\"name\":\"Bodyjar\",\"street_cred\":1}}", band.to_json
      assert_xml_equal "<band><name>Bodyjar</name><street_cred>1</street_cred></band>", band.to_xml
    end

    it "allows extending with different representers subsequentially" do
      module SongXmlRepresenter
        include Representable::XML
        property :name, :from => "name", :attribute => true
      end

      module SongJsonRepresenter
        include Representable::JSON
        property :name
      end

      @song = Song.new("Days Go By")
      assert_xml_equal "<song name=\"Days Go By\"/>", @song.extend(SongXmlRepresenter).to_xml
      assert_equal "{\"name\":\"Days Go By\"}", @song.extend(SongJsonRepresenter).to_json
    end
  end



  describe "#property" do
    it "creates accessors for the attribute" do
      @band = PunkBand.new
      assert @band.name = "Bad Religion"
      assert_equal "Bad Religion", @band.name
    end

    describe ":from" do
      # TODO: do this with all options.
      it "can be set explicitly" do
        band = Class.new(Band) { property :friends, :from => :friend }
        assert_equal "friend", band.representable_attrs.last.from
      end

      it "is infered from the name implicitly" do
        band = Class.new(Band) { property :friends }
        assert_equal "friends", band.representable_attrs.last.from
      end
    end

    describe ":accessor" do
      it "doesn't add methods when false" do
        klass = Class.new(Band) { property :friends, :accessors => false }
        band = klass.new
        assert ! band.respond_to?(:friends)
        assert ! band.respond_to?("friends=")
      end
    end
  end

  describe "#collection" do
    class RockBand < Band
      collection :albums
    end

    it "creates correct Definition" do
      assert_equal "albums", RockBand.representable_attrs.last.name
      assert RockBand.representable_attrs.last.array?
    end
  end


  describe "#representation_wrap" do
    class HardcoreBand
      include Representable
    end

    class SoftcoreBand < HardcoreBand
    end

    before do
      @band = HardcoreBand.new
    end


    it "returns false per default" do
      assert_equal nil, SoftcoreBand.new.send(:representation_wrap)
    end

    it "infers a printable class name if set to true" do
      HardcoreBand.representation_wrap = true
      assert_equal "hardcore_band", @band.send(:representation_wrap)
    end

    it "can be set explicitely" do
      HardcoreBand.representation_wrap = "breach"
      assert_equal "breach", @band.send(:representation_wrap)
    end
  end


  describe "#definition_class" do
    it "returns Definition class" do
      assert_equal Representable::Definition, Band.definition_class
    end
  end


  require 'representable/json'  # DISCUSS: i don't like the JSON requirement here, what about some generic test module?
  class PopBand
    include Representable::JSON
    property :name
    property :groupies
    attr_accessor :name, :groupies
  end

  describe "#update_properties_from" do
    before do
      @band = PopBand.new
    end

    it "copies values from document to object" do
      @band.update_properties_from({"name"=>"No One's Choice", "groupies"=>2}, {}, Representable::JSON)
      assert_equal "No One's Choice", @band.name
      assert_equal 2, @band.groupies
    end

    it "accepts :except option" do
      @band.update_properties_from({"name"=>"No One's Choice", "groupies"=>2}, {:except => [:groupies]}, Representable::JSON)
      assert_equal "No One's Choice", @band.name
      assert_equal nil, @band.groupies
    end

    it "accepts :include option" do
      @band.update_properties_from({"name"=>"No One's Choice", "groupies"=>2}, {:include => [:groupies]}, Representable::JSON)
      assert_equal 2, @band.groupies
      assert_equal nil, @band.name
    end

    it "always returns self" do
      assert_equal @band, @band.update_properties_from({"name"=>"Nofx"}, {}, Representable::JSON)
    end
  end

  describe "#create_representation_with" do
    before do
      @band = PopBand.new
      @band.name = "No One's Choice"
      @band.groupies = 2
    end

    it "compiles document from properties in object" do
      assert_equal({"name"=>"No One's Choice", "groupies"=>2}, @band.send(:create_representation_with, {}, {}, Representable::JSON))
    end

    it "accepts :except option" do
      hash = @band.send(:create_representation_with, {}, {:except => [:groupies]}, Representable::JSON)
      assert_equal({"name"=>"No One's Choice"}, hash)
    end

    it "accepts :include option" do
      hash = @band.send(:create_representation_with, {}, {:include => [:groupies]}, Representable::JSON)
      assert_equal({"groupies"=>2}, hash)

      hash = @band.send(:create_representation_with, {}, {:include => {groupies: nil}}, Representable::JSON)
      assert_equal({"groupies"=>2}, hash)
    end

    describe "nested object" do
      class Artist
        include Representable::JSON
        property :name
        collection :bands, class: PopBand
        attr_accessor :name, :bands
      end
      before do
        @artist = Artist.new
        @artist.name = "ABC"
        @artist.bands = [@band]
      end
      it "compiles document for nexted objects" do
        assert_equal({"name"=>"ABC", "bands" => [{"name"=>"No One's Choice", "groupies"=>2}]}, @artist.to_hash)
      end
      it "accepts nested :except option" do
        # it will remove whole bands
        assert_equal({"name"=>"ABC"}, @artist.to_hash(except: [bands: :name]))
      end
      it "accepts nested :include option" do
        assert_equal({"bands" => [{"name"=>"No One's Choice", "groupies"=>2}]}, @artist.to_hash(include: [bands: [:name, :groupies]]))
        assert_equal({"name"=>"ABC", "bands" => [{"groupies"=>2}]}, @artist.to_hash(include: [:name, bands: :groupies]))
      end
    end
  end


  describe "Config" do
    before do
      @config = Representable::Config.new
      PunkRock = Class.new
    end

    describe "wrapping" do
      it "returns false per default" do
        assert_equal nil, @config.wrap_for("Punk")
      end

      it "infers a printable class name if set to true" do
        @config.wrap = true
        assert_equal "punk_rock", @config.wrap_for(PunkRock)
      end

      it "can be set explicitely" do
        @config.wrap = "Descendents"
        assert_equal "Descendents", @config.wrap_for(PunkRock)
      end
    end
  end

  describe "Represents" do
    before do
      @class = Class.new do
        extend Representable::Represents
        represents :json, :with => :whatever
        represents "application/order-json", :with => :special
      end
    end

    it "allows mapping formats to representers" do
      assert_equal :whatever, @class.representer[:json]
      assert_equal :special, @class.representer["application/order-json"]
    end
  end

  describe "id attribute" do
    it "should override object id" do
      representer = Module.new do
        include Representable::JSON
        property :id
      end

      inst = Object.new
      inst.extend representer
      inst.from_hash "id" => 123
      assert_equal 123, inst.id
    end
    module Base
        include Representable::JSON
        property :id
    end

    module Child
      include Representable::JSON
      include Base
      property :name
    end

    it "should handle inherit correctly" do
      inst = Object.new
      inst.extend Child
      inst.from_hash "id" => 123, "name" => "name"
      assert_equal 123, inst.id
      assert_equal "name", inst.name
    end

    it "should support include directtly" do
      klass = Class.new do
        include Representable::JSON
        include Child
      end
      associate_presenter = Module.new do
        include Representable::JSON
        include Child
        property :associate, :class => klass
      end

      inst = Object.new
      inst.extend associate_presenter
      inst.from_hash({"id" => 1, "name" => "name", "associate" => { "id" => 2, "name" => "name2" }})
      assert_equal 1, inst.id
      assert_equal "name", inst.name
      assert_equal 2, inst.associate.id
      assert_equal "name2", inst.associate.name
    end
  end
end
