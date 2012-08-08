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
        expect(config.dir).to eq(File.expand_path("~/apps/main"))
      end

      it "includes a default host" do
        expect(subject.apps["admin"].host).to eq("127.0.0.1")
      end

      it "includes a default idle timeout" do
        expect(subject.apps["admin"].idle_timeout).to eq(Ringleader::Config::DEFAULT_IDLE_TIMEOUT)
      end

      it "sets a default start timeout" do
        expect(subject.apps["admin"].startup_timeout).to eq(Ringleader::Config::DEFAULT_STARTUP_TIMEOUT)
      end

      it "sets the config name to match the key in the config file" do
        expect(subject.apps["admin"].name).to eq("admin")
      end

      it "sets the env hash to an empty hash if not specified" do
        expect(subject.apps["main_site"].env).to eq({})
        expect(subject.apps["admin"].env).to have_key("OVERRIDE")
      end
    end
  end

  context "when initialized with an invalid config" do
    subject { Ringleader::Config.new "spec/fixtures/invalid.yml" }

    it "raises an exception" do
      expect { subject.apps }.to raise_error(/command.*missing/i)
    end
  end

  context "with a config without an app port" do
    it "raises an exception" do
      expect {
        Ringleader::Config.new("spec/fixtures/no_app_port.yml").apps
      }.to raise_error(/app_port/)
    end
  end

  context "with a config without a server port" do
    it "raises an exception" do
      expect {
        Ringleader::Config.new("spec/fixtures/no_server_port.yml").apps
      }.to raise_error(/server_port/)
    end
  end

  context "with a config with an 'rvm' key instead of a 'command'" do
    it "replaces the rvm command with a command to use rvm" do
      config = Ringleader::Config.new "spec/fixtures/rvm.yml"
      expect(config.apps["rvm_app"].command).to match(/rvm.*rvmrc.*exec.*foreman/)
    end
  end

  context "with a config with a 'rbenv' key instead of 'command'" do
    it "replaces the 'rbenv' command with an rbenv command and environment" do
      config = Ringleader::Config.new "spec/fixtures/rbenv.yml"
      expect(config.apps["rbenv_app"].command).to eq("rbenv exec bundle exec foreman start")
      expect(config.apps["rbenv_app"].env).to have_key("RBENV_VERSION")
      expect(config.apps["rbenv_app"].env["RBENV_VERSION"]).to eq(nil)
    end
  end

end
