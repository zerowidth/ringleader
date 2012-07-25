if fork
  if fork
    puts "parent #{$$}"
    sleep 1
    puts "exiting #{$$}"
  else
    puts "child 2 #{$$}"
    sleep 0.25
    puts "child 2 exiting #{$$}"
  end
else
  puts "child #{$$}"
  sleep 0.5
  puts "exiting #{$$}"
end
