#!/usr/bin/env ruby -wKU


pid = Process.spawn "ruby wait_fork_tree.rb", :pgroup => true
puts "forked: #{pid}"

# unicorn-style
def reap(pid)
  begin
    wpid = Process.waitpid(-1)#, Process::WNOHANG)
    if wpid
      puts "got child pid #{wpid}"
    else
      puts "no child pid"
      # return
    end
  rescue Errno::ECHILD
    puts "NO CHILD"
    break
  end while true
end

reap pid

# welp, can't wait for grandchildren. oh well.
