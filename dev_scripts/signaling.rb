require "celluloid"

class S
  include Celluloid
  include Celluloid::Logger

  def go
    debug "sleeping..."
    sleep 1
    debug "awake. signaling awake"
    signal :awake, true
  end
end

class C
  include Celluloid
  include Celluloid::Logger

  def initialize(n, s)
    @n, @s = n, s
    await!
  end

  def await
    debug "#{@n} waiting"
    @s.wait :awake
    debug "#{@n} signaled"
  end
end


class Foo
  include Celluloid
  include Celluloid::Logger

  def go
    after(1) { ping! }
    debug "waiting"
    ping = wait :ping
    debug "got a ping! #{ping}"
  end

  def ping
    signal :ping, "lol"
  end
end

# s = S.new
# s.go!
# 5.times { |n| C.new(n, s) }
# sleep 2
# puts "my turn"
# s.wait :awake

Foo.new.go!
sleep 5
