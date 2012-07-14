source :rubygems

gem "celluloid"
gem "celluloid-io"

group :development do
  gem "foreman", :git => "https://github.com/ddollar/foreman.git"
end

group :development, :test do
  gem "rspec"
  gem "guard-rspec"

  if RUBY_PLATFORM =~ /darwin/
    gem "growl"
    gem "rb-fsevent"
  end
end
