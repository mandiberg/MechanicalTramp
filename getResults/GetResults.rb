#!/usr/bin/env ruby

# Thomas R Storey
# 7.7.15
# For Mechanical Tramp

begin
  require 'rubygems'
  require 'curb'
  require 'mturk'
  require 'yaml'
  rescue LoadError
end

# Run this after uploading all HITs for the scene with sendHITs,
# and then waiting a while for results to come in. This script downloads any
# available result files, and records them in the "reviewing" file.
# After running this script, use the reviewing file as a reference to keep
# track of which videos to accept or reject, copying lines as neessary to your
# tsv file list of files to approve and reject.

# if only some of the files for a scene are submitted, only those HITs will be
# touched by this script. Run this script again to download the rest later
# once they have been submitted. Previously reviewed HITs will be ignored (as
# long as they are still recorded in the "reviewing" file).

# usage: ./GetResults.rb

# example: ./getResults/GetResults.rb

# configuration: see mtramp.yml

@config = YAML.load_file(File.join( File.expand_path(Dir.pwd), 'mtramp.yml' ))
mtf = File.join( File.expand_path(Dir.pwd), 'mturk.yml' )
@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => mtf

def getReviewingHITs reviewingFile
  # create the array of HITId's that have already been downloaded
  reviewing = []
  if File.file? reviewingFile
    File.readlines(reviewingFile).each_with_index do |line, index|
      if index == 0
        next
      end
      hitid, hitTypeId, vidnum, dled = line.split("\t")
      reviewing.push hitid.strip
    end
  else
    f = File.new(reviewingFile, "w+");
    f.write("HITId\tHITTypeId\tFileNumber\tDownloaded\n")
    f.close
  end
  return reviewing
end

def getVideoMap successFile
  # Put the success file data into a Hash so we can map HITid -> video file
  videoMap = Hash.new
  File.readlines(successFile).each_with_index do |line, index|
    # skip first line
    if index == 0
      next
    end
    id, typeid, num = line.split("\t")
    videoMap[id] = num.strip
  end
  return videoMap
end

def getResults( successFile, outputFile, reviewingFile )
  videoMap = getVideoMap successFile
  reviewing = getReviewingHITs reviewingFile

  # Loads the .success file containing the HIT IDs and HIT Type IDs of HITs
  # to be retrieved.
  success = Amazon::Util::DataReader.load( successFile, :Tabular )
  # Retrieves the submitted results of the specified HITs from Mechanical Turk
  results = @mturk.getHITResults(success)
  # parse answers so they're easier to digest
  results.each { |assignment|
    aid = assignment[:AssignmentId]
    dir = @config["ResultsDirectory"]
    fn = @config["ResultFilePrefix"].sub("scene_name", @config["SceneName"])
    filenum = videoMap[assignment[:HITId]]
    fn = fn + filenum + @config["ClipFileExt"]
    downloaded = false
    path = dir+fn
    # check if we are already reviewing this one
    if reviewing.include? assignment[:HITId]
      puts "Skipping HIT #{assignment[:HITId]} because we already downloaded it"
      next
    end
    url = ''
    begin
      url = @mturk.getFileUploadURL(:AssignmentId => aid, :QuestionIdentifier => 1)
    rescue Amazon::WebServices::Util::ValidationException
      puts "No valid upload url for HIT #{assignment[:HITId]}. "
    end
    # If the link exists, curl it to a file
    if(url.size > 0)
      downloaded = true
      puts "Curling file from: " + url[:FileUploadURL]
      puts "Writing file to: " + dir + fn
      curl = Curl::Easy.new(url[:FileUploadURL])
      curl.on_body {|d|
        File.open(File.expand_path(Dir.pwd) + path, "a") {|f| f.write d }
      }
      curl.perform
      assignment[:Answers] = @mturk.simplifyAnswer( assignment[:Answer] )
    end
    # set HIT to "reviewing"
    puts "Setting HIT #{assignment[:HITId]} to 'Reviewing' status"
    @mturk.setHITAsReviewing(:HITId => assignment[:HITId])
    puts "Writing HIT #{assignment[:HITId]} to .reviewing file"
    # record the result in the reviewing file
    f = File.open(reviewingFile, "a");
    if downloaded
      f.write("#{assignment[:HITId]}\t#{assignment[:HITTypeId]}\t#{fn}\t1\n")
    else
      f.write("#{assignment[:HITId]}\t#{assignment[:HITTypeId]}\t#{fn}\t0\n")
    end
    f.close
  }

  # Writes the submitted results to the defined output file.
  # The output file is a tab delimited file containing all relevant details
  # of the HIT and assignments. The submitted results are included as the last
  # set of fields and are represented as tab separated question/answer pairs
  Amazon::Util::DataReader.save( outputFile, results, :Tabular )
  puts "Results have been written to: #{outputFile}"

end

# get configuration settings
sf = @config["SuccessFile"].sub("scene_name", @config["SceneName"])
rlf = @config["ResultsLogFile"].sub("scene_name", @config["SceneName"])
rvf = @config["ReviewingFile"].sub("scene_name", @config["SceneName"])
getResults sf, rlf, rvf
