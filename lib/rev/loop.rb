#--
# Copyright (C)2007 Tony Arcieri
# You can redistribute this under the terms of the Ruby license
# See file LICENSE for details
#++

require File.dirname(__FILE__) + '/../rev'

module Rev
  class Loop
    @@default_loop = {}
    attr_reader :watchers
    
    # Retrieve the default event loop for the current thread
    def self.default
      # Well awesome, variables stashed in Thread.current[]
      # are only accessible in the context of the Fiber where
      # they were stored.  Soo... we need to make our own
      # thread-local store if we want Fiber compatibility
      #
      # I think this should be sufficient... but it may need
      # a mutex or something, got me.
      @@default_loop[Thread.current] ||= Loop.new
    end

    # Create a new Rev::Loop
    #
    # Options:
    #
    # :skip_environment (boolean)
    #   Ignore the $LIBEV_FLAGS environment variable
    #
    # :fork_check (boolean)      
    #   Enable autodetection of forks
    #
    # :backend
    #   Choose the default backend, one (or many in an array) of:
    #     :select (most platforms)
    #     :poll   (most platforms except Windows)
    #     :epoll  (Linux)
    #     :kqueue (BSD/Mac OS X)
    #     :port   (Solaris 10)
    #
    def initialize(options = {})
      @watchers = []
      @active_watchers = 0
      
      flags = 0

      options.each do |option, value|
        case option
        when :skip_environment
          flags |= EVFLAG_NOEV if value
        when :fork_check
          flags |= EVFLAG_FORKCHECK if value
        when :backend
          value = [value] unless value.is_a? Array
          value.each do |backend|
            case backend
            when :select then flags |= EVBACKEND_SELECT
            when :poll   then flags |= EVBACKEND_POLL
            when :epoll  then flags |= EVBACKEND_EPOLL
            when :kqueue then flags |= EVBACKEND_KQUEUE
            when :port   then flags |= EVBACKEND_PORT
            else raise ArgumentError, "no such backend: #{backend}"
            end
          end
        else raise ArgumentError, "no such option: #{option}"
        end
      end

      @loop = ev_loop_new(flags)
    end
    
    # Attach a watcher to the loop
    def attach(watcher)
      watcher.attach self
    end

    # Run the event loop and dispatch events back to Ruby.  If there
    # are no watchers associated with the event loop it will return
    # immediately.  Otherwise, run will continue blocking and making
    # event callbacks to watchers until all watchers associated with
    # the loop have been disabled or detached.  The loop may be 
    # explicitly stopped by calling the stop method on the loop object.
    def run
      raise RuntimeError, "no watchers for this loop" if @watchers.empty?

      @running = true
      while @running and not @active_watchers.zero?
        run_once
      end
    end

    # Stop the event loop if it's running
    def stop
      raise RuntimeError, "loop not running" unless @running
      @running = false
    end
    
    # Does the loop have any active watchers?
    def has_active_watchers?
      @active_watchers > 0
    end
    
    #######
    private
    #######
    
    EVFLAG_NOENV     = 0x1000000  # do NOT consult environment
    EVFLAG_FORKCHECK = 0x2000000  # check for a fork in each iteration

    EVBACKEND_SELECT = 0x00000001 # supported about anywhere 
    EVBACKEND_POLL   = 0x00000002 # !win 
    EVBACKEND_EPOLL  = 0x00000004 # linux 
    EVBACKEND_KQUEUE = 0x00000008 # bsd 
    EVBACKEND_PORT   = 0x00000020 # solaris 10
  end
end
