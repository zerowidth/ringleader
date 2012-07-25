trap "INT" do
  STDERR.puts "BRO DON'T INTERRUPT ME"
end

trap "HUP" do
  STDERR.puts "LOL, NOT QUITTING"
end

at_exit do
  STDERR.puts "FUCK YOUUUUUUU"
end

sleep
