require "spec_helper"

describe Ringleader::Config do

  context "when initialized with a config file" do
    subject { Ringleader::Config.new "spec/fixtures/config.yml" }

    describe "#apps" do
      it "returns a list of app configs" do
        expect(subject.apps).to have(3).entries
      end

      it "returns a hash of configurations" do
        config = subject.apps["main_site"]
        expect(config.dir).to_not eq(nil)
      end
    end
  end

  context "when initialized with an invalid config" do
    subject { Ringleader::Config.new "spec/fixtures/invalid.yml" }

    it "raises an exception" do
      expect { subject.apps }.to raise_error(/command.*missing/i)
    end
  end

end
