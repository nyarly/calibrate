require 'calibrate'

describe Calibrate::Configurable do
  class TestSuperStruct
    include Calibrate::Configurable

    setting(:three, 3)
    required_field(:four)
    required_field(:override)
  end

  class TestStruct < TestSuperStruct
    settings(:one => 1, :two => nested(:a => "a"){ required_field(:b)} )
    nil_field(:five)

    def override
      17
    end
  end

  subject do
    TestStruct.new.setup_defaults
  end

  it "should set defaults" do
    expect(subject.one).to eq(1)
    expect(subject.two.a).to eq("a")
    expect(subject.three).to eq(3)
    expect(subject.five).to be_nil
  end

  it "#to_hash" do
    hash = subject.to_hash
    expect(hash[:one]).to eq(1)
    expect(hash[:two][:a]).to eq("a")
  end

  it "#from_hash" do
    subject.from_hash({:one => 111, "two" => { :a => "aaa" }})

    expect(subject.one).to eq(111)
    expect(subject.two.a).to eq("aaa")
  end

  it "should complain about unset required fields" do
    expect do
      subject.check_required
    end.to raise_error(Calibrate::RequiredFieldUnset)
  end

  it "should complain about unset nested required fields" do
    subject.four = 4
    expect do
      subject.check_required
    end.to raise_error(Calibrate::RequiredFieldUnset)
  end

  it "should not complain when required fields are set" do
    subject.four = 4
    subject.two.b = "b"
    expect do
      subject.check_required
    end.to_not raise_error
    expect(subject.override).to eq(17)
  end

  it "should inspect cleanly" do
    expect(subject.inspect).to be_a(String)
  end

  describe "with DirectoryStructure" do
    class DirectoryThing
      include Calibrate::Configurable
      include DirectoryStructure

      dir(:ephemeral_mountpoint,
          dir(:bundle_workdir, "bundle_workdir",
              path(:bundle_manifest),
              path(:credentials_archive, "aws-creds.tar.gz"),
              dir(:credentials_dir, "aws-creds",
                  path(:private_key_file, "pk.pem"),
                  path(:certificate_file, "cert.pem")
                 )
             )
         )

      dir(:next_to_me, "rainbow", dir(:in_there, "a_place", path(:nearby, "a.file")))

      path(:loose_path, "here")
    end

    describe "distinctness" do
      let :one do
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
        end
      end

      let :other do
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
        end
      end

      it "should have same values" do
        expect(one.bundle_workdir.relative_path).to eq(other.bundle_workdir.relative_path)
      end

      it "should have different actual objects" do
        expect(one.bundle_workdir.relative_path).to_not equal other.bundle_workdir.relative_path
        expect(one.bundle_workdir).to_not equal other.bundle_workdir
      end

    end

    def subject
      DirectoryThing.new.tap do |thing|
        thing.setup_defaults
      end
    end

    it "should complain about missing fields" do
      expect do
        subject.check_required
      end.to raise_error(/Required field/)
    end

    it "should inspect cleanly" do
      expect(subject.inspect).to be_a(String)
    end

    describe "with root path configured, but missing a relative path" do
      def subject
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
          thing.ephemeral_mountpoint.absolute_path = "/tmp"
          thing.resolve_paths
        end
      end

      it "should complain about missing fields" do
        expect do
          subject.check_required
        end.to raise_error(/Required field/)
      end
    end

    describe "with required paths configured" do
      subject :thing do
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
          thing.ephemeral_mountpoint.absolute_path = "/tmp"
          thing.bundle_manifest.relative_path = "image.manifest.xml"
          thing.resolve_paths
        end
      end

      it "should not complain about required fields" do
        expect do
          subject.check_required
        end.not_to raise_error
      end

      it{ expect(thing.nearby.absolute_path).to match(%r"rainbow/a_place/a.file$")}
      it{ expect(thing.nearby.absolute_path).to match(%r"^#{subject.absolute_path}") }

      it{ expect(thing.certificate_file.absolute_path).to eq("/tmp/bundle_workdir/aws-creds/cert.pem")}
      it{ expect(thing.bundle_manifest.absolute_path).to eq("/tmp/bundle_workdir/image.manifest.xml") }
      it{ expect(thing.credentials_dir.absolute_path).to eq("/tmp/bundle_workdir/aws-creds") }
    end
  end

  describe "multiple instances" do
    class MultiSource
      include Calibrate::Configurable

      setting :one, 1
      setting :nest, nested{
        setting :two, 2
      }
    end

    let :first do
      MultiSource.new.setup_defaults
    end

    let :second do
      MultiSource.new.setup_defaults
    end

    before :each do
      first.one = "one"
      first.nest.two = "two"
      second
    end

    it "should not have any validation errors" do
      expect do
        first.check_required
        second.check_required
      end.not_to raise_error
    end

    it "should accurately reflect settings" do
      expect(first.one).to eq("one")
      expect(second.one).to eq(1)

      expect(first.nest.two).to eq("two")
      expect(second.nest.two).to eq(2)
    end
  end

  describe "copying settings" do
    class LeftStruct
      include Calibrate::Configurable

      setting(:normal, "1")
      setting(:nested, nested{
        setting :value, "2"
      })
      setting(:no_copy, 2).isnt(:copiable)
      setting(:no_proxy, 3).isnt(:proxiable)
      setting(:no_nothing, 4).isnt(:copiable).isnt(:proxiable)
      setting(:not_on_target, 5)
    end

    class RightStruct
      include Calibrate::Configurable

      required_fields(:normal, :nested, :no_copy, :no_proxy, :no_nothing)
    end

    let :left do
      LeftStruct.new.setup_defaults
    end

    let :right do
      RightStruct.new.setup_defaults
    end

    it "should make copies not references" do
      left.copy_settings_to(right)
      expect(right.normal).to eq(left.normal)
      expect(right.normal).to_not equal(left.normal)
      expect(right.nested.value).to eq(left.nested.value)
      expect(right.nested).to_not equal(left.nested)
      expect(right.nested.value).to_not equal left.nested.value
    end

    it "should not copy no_copy" do
      left.copy_settings_to(right)
      expect(right.field_unset?(:normal)).to eq(false)
      expect(right.normal).to eq("1")
      expect(right.field_unset?(:no_copy)).to eq(true)
      expect(right.field_unset?(:no_proxy)).to eq(false)
      expect(right.no_proxy).to eq(3)
      expect(right.field_unset?(:no_nothing)).to eq(true)
    end

    it "should not proxy no_proxy" do
      left.proxy_settings.to(right)
      expect(right.field_unset?(:normal)).to eq(false)
      expect(right.normal).to eq("1")
      expect(right.field_unset?(:no_copy)).to eq(false)
      expect(right.no_copy).to eq(2)
      expect(right.field_unset?(:no_proxy)).to eq(true)
      expect(right.field_unset?(:no_nothing)).to eq(true)
    end
  end
end
