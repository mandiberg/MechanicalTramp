#!/usr/bin/env ruby

# Copyright:: Copyright (c) 2007 Amazon Technologies, Inc.
# License::   Apache License, Version 2.0
# Modified by Thomas R Storey for Mechanical Tramp

# Totally wipes clean your HITs
# Run this script after you have downloaded and reviewed all the HITs you need.
# Will expire, reject and dispose of any hits that still exist.

# usage: ./BlankSlate.rb

# configuration: none.

begin
  require 'rubygems'
  require 'mturk'
  require 'yaml'
rescue LoadError
end

config = YAML.load_file(File.join( File.expand_path(Dir.pwd), 'mtramp.yml' ))
mtf = File.join( File.expand_path(Dir.pwd), 'mturk.yml' )
@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => mtf

def forceExpire(id)
  # A HIT has to be expired before it can be disposed of
  print "Ensuring HIT #{id} is expired: "
  begin
    @mturk.forceExpireHIT( :HITId => id )
  rescue => e
    raise e unless e.message == 'AWS.MechanicalTurk.InvalidHITState'
  end
  puts "OK"
end

def rejectRemainingAssignments(id)
  # reject all assignments for a particular HIT id
  print "Rejecting remaining assignments for HIT #{id}: "
  count = 0
  @mturk.getAssignmentsForHITAll( :HITId => id ).each do |assignment|
    if assignment[:AssignmentStatus] == 'Submitted'
      @mturk.rejectAssignment :AssignmentId => assignment[:AssignmentId]
    end
    count += 1
  end
  puts "OK (Rejected #{count})"
end

def dispose(id)
  # once a hit is expired and approved/rejected, it can be disposed of
  # this removes it from the server altogether
  print "Disposing HIT #{id}: "
  @mturk.disposeHIT( :HITId => id )
  puts "OK"
end

def purge
  # this function loops through your accounts HITs until they are all disposed
  # if it misses one, it will check again and try to dispose of it again
  # TODO: exception handling to stop looping if there are errors preventing it
  # from finishing
  hit_ids = @mturk.searchHITsAll.collect {|hit| hit[:HITId] }
  puts "Found #{hit_ids.size} HITs"

  return false if hit_ids.size == 0

  hit_ids.each do |id|
    begin
      forceExpire id
      rejectRemainingAssignments id
      dispose id
    rescue Exception => e
      raise e if e.is_a? Interrupt
      puts e.inspect
    end
  end

  return true
end

while purge
  puts 'Ensuring there are no more hits...'
end

puts 'You now have a blank slate'
