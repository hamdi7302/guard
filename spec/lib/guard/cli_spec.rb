require "spec_helper"
require "guard/cli"

RSpec.shared_examples "avoids Bundler warning" do |meth|
  it "does not show the Bundler warning" do
    expect(Guard::UI).to_not receive(:info).with(/Guard here!/)
    subject.send(meth)
  end
end

RSpec.shared_examples "shows Bundler warning" do |meth|
  it "shows the Bundler warning" do
    expect(Guard::UI).to receive(:info).with(/Guard here!/)
    subject.send(meth)
  end
end

RSpec.shared_examples "gem dependency warning" do |meth|
  let(:guard_options) { double("hash_with_options") }
  before do
    allow(Guard).to receive(:options).and_return(guard_options)
    @bundler_env = {
      "BUNDLE_GEMFILE" => ENV.delete("BUNDLE_GEMFILE"),
      "RUBYGEMS_GEMDEPS" => ENV.delete("RUBYGEMS_GEMDEPS")
    }
  end

  after { ENV.update(@bundler_env) }

  context "without an existing Gemfile" do
    before { expect(File).to receive(:exist?).with("Gemfile") { false } }
    include_examples "avoids Bundler warning", meth
  end

  context "with an existing Gemfile" do
    before { allow(File).to receive(:exist?).with("Gemfile") { true } }

    context "with Bundler" do
      before { ENV["BUNDLE_GEMFILE"] = "Gemfile" }
      include_examples "avoids Bundler warning", meth
    end

    context "without Bundler" do
      before { ENV["BUNDLE_GEMFILE"] = nil }

      context "with Rubygems Gemfile autodetection or custom Gemfile" do
        before { ENV["RUBYGEMS_GEMDEPS"] = "-" }
        include_examples "avoids Bundler warning", meth
      end

      context "without Rubygems Gemfile handling" do
        before { ENV["RUBYGEMS_GEMDEPS"] = nil }

        context "with :no_bundler_warning option" do
          before { @options[:no_bundler_warning] = true }
          include_examples "avoids Bundler warning", meth
        end

        context "without :no_bundler_warning option" do
          include_examples "shows Bundler warning", meth
        end
      end
    end
  end
end

describe Guard::CLI do
  let(:guard)         { Guard }
  let(:ui)            { Guard::UI }
  let(:dsl_describer) { instance_double(::Guard::DslDescriber) }

  before do
    @options = {}
    allow(subject).to receive(:options).and_return(@options)
  end

  describe "#start" do
    include_examples "gem dependency warning", :start

    before { allow(Guard).to receive(:start) }

    it "delegates to Guard.start" do
      expect(Guard).to receive(:start)

      subject.start
    end
  end

  describe "#list" do
    it "outputs the Guard plugins list" do
      expect(::Guard::DslDescriber).to receive(:new) { dsl_describer }
      expect(dsl_describer).to receive(:list)

      subject.list
    end
  end

  describe "#notifiers" do
    it "outputs the notifiers list" do
      expect(::Guard::DslDescriber).to receive(:new) { dsl_describer }
      expect(dsl_describer).to receive(:notifiers)

      subject.notifiers
    end
  end

  describe "#version" do
    it "shows the current version" do
      expect(STDOUT).to receive(:puts).with(/#{ ::Guard::VERSION }/)

      subject.version
    end
  end

  describe "#init" do
    include_examples "gem dependency warning", :init

    before do
      allow(Guard::Guardfile).to receive(:create_guardfile)
      allow(Guard::Guardfile).to receive(:initialize_all_templates)
    end

    context "with any options" do
      before { @options[:bare] = true }

      it "should call Guard.reset_options before using ::Guard.UI" do
        reset_called = false
        reset_called_before_creating = false
        expect(::Guard).to receive(:reset_options).with(@options) do
          reset_called = true
        end

        expect(Guard::Guardfile).to receive(:create_guardfile) do
          reset_called_before_creating = reset_called
        end

        subject.init
        expect(reset_called).to be(true)
        expect(reset_called_before_creating).to be(true)
      end
    end

    context "with no bare option" do
      before { @options[:bare] = false }

      it "creates a Guardfile by delegating to Guardfile.create_guardfile" do
        expect(Guard::Guardfile).to receive(:create_guardfile).
          with(abort_on_existence: false)

        subject.init
      end

      it "initializes templates of all installed Guards" do
        expect(Guard::Guardfile).to receive(:initialize_all_templates)

        subject.init
      end

      it "initializes each passed template" do
        expect(Guard::Guardfile).to receive(:initialize_template).with("rspec")
        expect(Guard::Guardfile).to receive(:initialize_template).with("pow")

        subject.init "rspec", "pow"
      end

      context "when passed a guard name" do
        it "initializes the template of the passed Guard" do
          expect(Guard::Guardfile).to receive(:initialize_template).
            with("rspec")

          subject.init "rspec"
        end
      end
    end

    context "with the bare option" do
      before { @options[:bare] = true }

      it "Only creates the Guardfile without initialize any Guard template" do
        expect(Guard::Guardfile).to receive(:create_guardfile)
        expect(Guard::Guardfile).to_not receive(:initialize_template)
        expect(Guard::Guardfile).to_not receive(:initialize_all_templates)

        subject.init
      end
    end

  end

  describe "#show" do
    it "outputs the Guard::DslDescriber.list result" do
      expect(::Guard::DslDescriber).to receive(:new) { dsl_describer }
      expect(dsl_describer).to receive(:show)

      subject.show
    end
  end
end
