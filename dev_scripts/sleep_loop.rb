def log(msg)
  STDOUT.puts "#{$$} stdout #{msg}"
  STDOUT.flush
  STDERR.puts "#{$$} stderr #{msg}"
end

%w(HUP INT QUIT ILL TRAP ABRT EMT FPE KILL BUS SEGV SYS PIPE ALRM TERM URG STOP
   TSTP CONT CHLD TTIN TTOU IO XCPU XFSZ VTALRM PROF WINCH INFO USR1
   USR1).each.with_index do |signal, i|
  trap(signal) {
    log signal
    log "waiting a second"
    sleep 1
    log "exiting"
    exit i
  }
end

times = Integer(ARGV[0] || "120")
times.times do |n|
  sleep 1
  log n + 1
end
log "loop complete"

at_exit { log "exiting" }
