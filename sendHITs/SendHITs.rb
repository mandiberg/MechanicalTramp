#!/usr/bin/ruby
begin
  require 'rubygems'
  require 'mturk'
  require 'yaml'
rescue LoadError
end

# Run this after configuring the settings for your scene in mtramp.yml.
# Will upload HITs to the MechanicalTurk depending on the configuration.

# usage: ./sendHITs/SendHITs.rb

# configuration: see mtramp.yml

@config = YAML.load_file(File.join( File.expand_path(Dir.pwd), ARGV[0] ))

mtf = File.join( File.expand_path(Dir.pwd), 'mturk.yml' )

@host = YAML.load_file(mtf)["Host"]

@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => mtf

def checkFunds
  # just a safety function to make sure we have enough money to pay for a HIT
  available = @mturk.availableFunds
  puts "Account balance: %.2f" % available
  return available > @config["ClipPrice"]
end

def generateHIT(url, vfileName, vfileNum, qfile, successfile)
  # format question file
  question = File.read(qfile)
  question = question.gsub(/%%%path%%%/, url)
  question = question.gsub(/%%%filename%%%/, vfileName)
  # use question to make and upload HIT
  result = createNewHIT question
  # record the upload in the success file (append)
  open(successfile, 'a') { |f|
    f.puts "#{result[:HITId]}\t#{result[:HITTypeId]}\t#{vfileNum}"
    f.close
  }

end

def createNewHIT q
  # create a HIT from the configuration parameters in mtramp.yml
  title = @config["QuestionTitle"]
  desc = @config["QuestionDescription"]
  keywords = @config["QuestionKeywords"]
  qualReq = {}
  qualReqs = []
  if(@config.has_key?("Qualification"))
    qualReq = { :QualificationTypeId => @config["Qualification"]["type"],
                :Comparator => @config["Qualification"]["comparator"],
                :LocaleValue => {:Country => @config["Qualification"]["parameter"]}, }
    # The create HIT method takes in an array of QualificationRequirements since a HIT can have multiple qualifications.
    qualReqs = [qualReq]
  end

  numAssignments = 1
  # createHIT takes the parameters and uploads, returning a result object that
  # tells us if it was successful
  # TODO: some exception handling here would be good...
  begin
    result = @mturk.createHIT(
      :Title => title,
      :Description => desc,
      :MaxAssignments => numAssignments,
      :Reward => {:Amount => @config["ClipPrice"], :CurrencyCode => 'USD'},
      :Question => q,
      :LifetimeInSeconds => @config["HITLifetime"],
      :AssignmentDurationInSeconds => @config["HITDuration"],
      :Keywords => keywords,
      :QualificationRequirement => qualReqs
    )
    puts "Created HIT: #{result[:HITId]}"
    puts "Location: #{getHITUrl(result[:HITTypeId])}"
  rescue #Amazon::WebServices::Util::ValidationException
    puts "could not create hit - do you have enough money?"
    checkFunds
  end
  return result
end

def getHITUrl hitTypeId
  # returns a different url depending on if we uploaded to the sandbox or
  # production servers
  if @host == "Sandbox"
    # Sandbox Url
    return "http://workersandbox.mturk.com/mturk/preview?groupId=#{hitTypeId}"
  elsif @host == "Prod"
    # Production Url
    return "https://www.mturk.com/mturk/preview?groupId=#{hitTypeId}"
  end
end

def getFilenames clips
  # use the method configured in mtramp.yml to get a list of filenames to sendHITs
  # with the HITs
  filenames = []
  if @config.has_key?("ClipsDirectory")
    # if clips directory, use the directory to get a list of filenames therein
    # puts Dir[]
    filenames = Dir[clips+"*"]
  elsif @config.has_key?("ClipsList")
    # if list file, open the file and use it to construct an array of filenames
    File.readlines(clips).each do |line|
      fn = line.strip+@config["ClipFileExt"]
      pf = @config["WebVideoPrefix"].sub("scene_name", @config["SceneName"])
      filenames << pf+fn
    end
  elsif @config.has_key?("ClipsRange")
    # if range, construct range of numbers, then use it to construct filename array
    range_start = @config["ClipsRange"][0]
    range_end = @config["ClipsRange"][1]
    (range_start..range_end).each do |num|
      fn = num.to_s.rjust(4, "0")+@config["ClipFileExt"]
      pf = @config["WebVideoPrefix"].sub("scene_name", @config["SceneName"])
      filenames << pf+fn
    end
  else
    abort("no clips retrieval @configuration specified! aborting...")
  end
  return filenames
end

def iterateHITs filenames
  # iterate across the provided list of filenames and create a HIT for each one
  pwd = File.expand_path(Dir.pwd)
  # get configurations parameters
  successFile = @config["SuccessFile"].sub("scene_name", @config["SceneName"]);
  prefix = @config["WebVideoPrefix"].sub("scene_name", @config["SceneName"]);
  clipsExt = @config["ClipFileExt"].delete "."
  puts successFile
  puts prefix
  # prepare success file
  f = File.new(successFile, "w");
  f.write("HITId\tHITTypeId\tFileNumber\n")
  f.close
  # create a HIT for each filename
  filenames.each do |filename|
    puts filename
    puts "#{prefix}0000.#{clipsExt}"
    # if file is in fact a video file that we chopped, then generate a HIT
    if /^#{prefix}\d{4}\.#{clipsExt}$/ =~ filename
      puts filename
      filenum = filename.scan(/\d{4}/).last
      puts filenum
      questionfile = @config["QuestionFile"].sub("scene_name", @config["SceneName"])
      generateHIT(@config["WebVideoDirectory"], filename, filenum, questionfile, successFile)
    end
  end
end

clipsdir = ""
clipslist = ""
clipsrange = []

# choose file list method depending on configuration
if @config.has_key?("ClipsDirectory")
  clipsdir = @config["ClipsDirectory"]
  iterateHITs getFilenames(clipsdir)
elsif @config.has_key?("ClipsList")
  clipslist = @config["ClipsList"]
  iterateHITs getFilenames(clipslist)
elsif @config.has_key?("ClipsRange")
  puts "sending hits by clips range"
  clipsrange = @config["ClipsRange"]
  iterateHITs getFilenames(clipsrange)
else
  abort("no clips retrieval configuration specified! aborting...")
end
