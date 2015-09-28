#!/usr/bin/env ruby

# Thomas R Storey
# 7.9.15
# For Mechanical Tramp

# Run this after downloading HIT responses to approve or reject as necessary
# Provide a tabulated list of HITs to accept and another to reject
# Anything not in these two lists will be left how they are
# All approved and rejected items will be immediately disposed of.

# usage: ./getResults/CompleteHITs.rb

# configuration: see mtramp.yml

begin
  require 'rubygems'
  require 'mturk'
  require 'yaml'
rescue LoadError
end

@config = YAML.load_file(File.join( File.expand_path(Dir.pwd), ARGV[0] ))

# videos are downloaded to /results subdirectory
mtf = File.join( File.expand_path(Dir.pwd), 'mturk.yml' )
@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => mtf

def getHITList filepath
  # create an array of HITIds (to approve or reject) from a tsv file
  array = []
  File.readlines(filepath).each_with_index do |line, index|
    if index == 0
      next
    end
    puts line
    hitid, hittypeid, num, downloaded = line.split("\t")
    array.push hitid.strip
  end
  return array
end

def completeHITs array, action
  # depending on the specified "action", approve or reject all the files in the
  # provided array
  count = 0
  puts "#{array.length} HITs to #{action}"
  if array.length
    array.each do |id|
      if id.length > 2
        forceExpire id
        # retrieve all the assignments for this HITId and approve/reject all
        @mturk.getAssignmentsForHITAll( :HITId => id ).each do |assignment|
          if action == "approve"
            puts "approving HIT #{id}"
            if assignment[:AssignmentStatus] == 'Submitted'
              @mturk.approveAssignment :AssignmentId => assignment[:AssignmentId]
            end
          elsif action == "reject"
            puts "rejecting HIT #{id}"
            if assignment[:AssignmentStatus] == 'Submitted'
              @mturk.rejectAssignment :AssignmentId => assignment[:AssignmentId]
            end
          end
        end
        count += 1
        dispose id
      end
    end
  end

  puts "#{action}'d #{count} HIT(s)"
end

def dispose(id)
  # disposing just removes the HIT from the server entirely
  print "Disposing HIT #{id}: "
  @mturk.disposeHIT( :HITId => id )
  puts "OK"
end

def forceExpire(id)
  # HITs have to be expired before they can be disposed of
  print "Ensuring HIT #{id} is expired: "
  begin
    @mturk.forceExpireHIT( :HITId => id )
  rescue => e
    raise e unless e.message == 'AWS.MechanicalTurk.InvalidHITState'
  end
  puts "OK"
end

approve = getHITList @config["ApproveFile"]
reject = getHITList @config["RejectFile"]
completeHITs approve, "approve"
completeHITs reject, "reject"
