trap("INT")  { STDERR.puts "#{$$} ignoring INT" }
trap("HUP")  { STDERR.puts "#{$$} ignoring HUP" }
trap("TERM") { STDERR.puts "#{$$} ignoring TERM" }

@extra = 0
3.times do |n|
  STDERR.puts "#{$$} forking (#{n})"
  if pid = fork
    STDERR.puts "#{$$} forked child #{pid}"
    break
  else
    @extra += 1
  end
end
sleep 10 + @extra * 2 # do clean up, eventually, with parent dying first
