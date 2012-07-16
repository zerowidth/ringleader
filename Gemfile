source :rubygems

gemspec

group :development do
  gem "foreman", :git => "https://github.com/ddollar/foreman.git"
end

group :development, :test do
  if RUBY_PLATFORM =~ /darwin/
    gem "growl"
    gem "rb-fsevent"
  end
end
