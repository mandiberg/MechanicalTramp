# Mechanical Tramp

### Production Process

#### Abridged Version

1. __Detect shots__
  * `shotdetect -i ModernTimes.mp4 -o ./shotdetect_out -s 60 -v`
* __Chop detected shots into individual files__
  * `./mechanical_chop.py -i ModernTimes.mp4 -o ./chop/out -x ./shotdetect_out/results.xml`
* __Test Shot files__
  * Put them in a VLC playlist and check them by eye :\
  * It only takes an hour and a half, and it's a good movie!
  * Manually chomp sections that don't come out well (especially transition shots)
* __Turking it__
  * Get AWS account, save access key and access key secret somewhere so you can use them later
  * Download and install latest JDK and JRE
  * Download and install Mechanical Turk Command Line Tools
  * Set MTURK_CMD_HOME and JAVA_HOME environment variables for your bash profile
  * edit `mturk.properties` in the command line tools folder to put in your access key and accesskey secret, and to set service_url and sandbox service_url to the correct addresses (see below)
  * test the command line tools by running `./getBalance.sh`
  * download and install ruby
  * `sudo gem install mturk` - you may have to mess with some dependencies
  * sign in at least once at requestersandbox.mturk.com so you can use the sandbox
  * `./BlankSlate.rb` Ensures there are no remaining leftover HITs
  * configure the mtramp.yml file to use the parameters you want - the details of that process are described as comments in the mtramp.yml file.
  * `./sendHITs/SendHITs.rb` sends HITs to MT
  * `./getResults/GetResults.rb` Downloads uploaded videos from HITs listed in the success file. (specified in mtramp.yml)
  * `./getResults/CompleteHITs.rb` Completes HITs by approving or rejecting them according to the approve and reject .tsv files (specified in mtramp.yml)
* __Make the movie__

#### Full Version

1. __Detect shots__
  *  from a shell: `shotdetect -i ModernTimes.mp4 -o ./shotdetect_out -s 60 -v`
  * this will generate several files. we are interested in `result.xml`
  * `shotdetect->content->body->shots` contains a list of shot metadata
  * Example: `<shot id="0" fduration="918" msduration="38288" fbegin="0" msbegin="0"/>`
  * `fduration` is the duration in frames, `msduration` is the duration in milliseconds, `fbegin` is the number of frame on which the shot begins, `msbegin` is the millisecond on which the shot begins.
*  __Chop into shot files__
  * from a shell: `./mechanical_chop.py -i ModernTimes.mp4 -o ./chop/out -x ./shotdetect_out/results.xml`
* __Test the shot files__
  * Put all the files into a vlc playlist and watch it to test and make sure they each are of a reasonable duration, from the beginning of one shot to the end of another
  * remove error shots that are only a couple of frames long (mechanical_chop does this automatically now!)
* __Generate Turk Tasks__
  1. Create AWS account (http://aws.amazon.com/)
  * Get access key and secret for your account __(not an IAM user!)__
  * Download Mechanical Turk Command Line Tools (https://requester.mturk.com/developer/tools/clt)
  * install latest JDK and JRE (1.8u45 as of this writing) (http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
  * set MTURK_CMD_HOME environment variable to point to where you extracted the command line tools (for me, this is `/home/thomas/aws-mturk-clt-1.3.1/`)
  * set JAVA_HOME environment variable to point to your JRE installation (for me, this is `/usr/lib/jvm/java-8-oracle/jre/`)
  * it may be worthwhile to edit your bash profile file (`~/.profile` in Ubuntu) to set these variables automatically.
  * navigate to the command line tools /bin directory (for me `/home/thomas/aws-mturk-clt-1.3.1/bin`)
  * edit the mturk.properties file in the following ways:
    * put your access key and access key secret in the appropriate lines (without the brackets)
    * change the service_url declaration to https://mechanicalturk.amazonaws.com/?Service=AWSMechanicalTurkRequester
    * change the sandbox service_url declaration (which is commented out to begin with) to https://mechanicalturk.sandbox.amazonaws.com/?Service=AWSMechanicalTurkRequester
  * test to make sure it works by running the command `./getBalance.sh`. You should get something like: `Your account balance: $0.00` instead of a giant stacktrace.
  * Now we can use the CLI. Next, we need the Ruby gem mturk https://requester.mturk.com/developer/tools/ruby
    * These steps you already have ruby and rubygems installed and configured correctly on your computer
    * use `sudo gem install mturk`
    * I also had install hoe manually: `sudo gem install hoe`
    * run `mturk` and follow the prompts to configure your credentials
    * navigate to mturk in your gems install directory (for me: `/var/lib/gems/1.9.1/gems/mturk-1.8.1`)
    * __IMPORTANT:__ go to https://requestersandbox.mturk.com/ and sign in there in order for the tests to work!
    * run 'sudo rake test' to make sure mturk is installed and configured correctly. If none of the tests fail, you're good!
    * for some reason, to get the results I had to put credentials in a YAML file, which can be found in this directory in the file called `mturk.yml`. Just copy your accesskey and accesskeyid into the appropriate lines of the file.
  * With mturk installed and ready, we can run the ruby files in the project that automate formatting and uploading the the videos as HITs
    * from this directory (where the readme file is) run the following commands:
      * `./BlankSlate.rb` : This will remove any existing HITs on mechanical turk, approving those that have been submitted
      * `./sendHITs/SendHITs.rb /sendHITs/clips http://trstorey.sysreturn.net/mechanicaltramp/clips/ /mtramp.question` :This will upload a HIT for every file in the clips folder (specified in the first argument). Make sure all your clips here and all your clips on the server where they are hosted have the same name!
* __Retrieve Results__
  * Wait a few days or something. Hopefully turkers will have uploaded some files!
  * For these next steps make sure you're in this directory again.
  * To get all the results for HITs that have been accepted and submitted, run this command: `./getResults/GetResults.rb ./getResults/testHit.success ./getResults/testHit.results` :This will download all the files in the success file (first argument) to the `/getResults/results` directory, logging all the output of the process to the testHit.results file.
  * Once you have all your files, you should approve them, so as to pay the people who made the files. To do that, run `./ApproveSubmitted.rb`
  * Ideally, we would like a more robust review/download/approval process. Download all the available data and keep track of which HITs are not yet reviewable. This can be done by creating a log file of all the HITIds which were reviewable and then checking that against the log of all HITIds for the process. The approval script should let the user approve or reject submissions one at a time, or all at once.
  * Generally it's probably best to wait until all HITs have been submitted before running GetResults. You can check if they are all done by going to https://requester.mturk.com/manage
  * Congratulations, you should now have all the of turker video clips on your computer! Now to turn them into one video.
* __Concatenating the Tramp__
  * As it is unlikely that all the videos we receive will be of the same filetype, resolution, bitrate, etc, I think it's best to just drag them all into an adobe premeire/final cut pro project and finesse it by hand. It's only ~600 videos!

### HIT description

####Mechanical Tramp

Please watch the video at the link below and reproduce it as a new video of your own creation, using the resources you have available. After watching the video, read the rest of the task description before doing anything else.

[video link]

The video is a single, complete shot from Charlie Chaplin's classic film "Modern Times". In addition to this HIT, we have also made HITs for every other shot in the film. We are going to use the videos you and other turkers produce to make a complete new version of the film.

It is not expected that the video you produce will look exactly like the shot from the original film. However, there are some rules we would like you to follow in order to make the eventual complete film understandable.
* The actor playing The Tramp (the main character, played by Charlie Chaplin in the original film), if present in the shot, must have a mustache (can be real, fake, or drawn on with a grease pencil or eyeliner), and must wear a white shirt, black pants and black shoes (oversized if possible).
* The actor playing The Gamin (the heroine of the original film), if present in the shot, must wear a dress and no shoes.
* Actors playing other characters should try to match that character's costume from the film as closely as possible, but it is not required to be completely accurate.
* The location where you choose to shoot the video is important. It should be your equivalent to what is seen in the film. If the clip is in a factory, shoot at a place of work. If it is in a home, shoot in a home. If it is on the street, shoot on a street local to you. If it's in a store, shoot in a store. Choose a place that has the same function for you as the location in the film has for the characters.
* Construct or acquire any props necessary to complete the action of the film. It will not always be possible to be completely accurate to the film, but do your best to come up with a creative solution.
* It will take multiple tries to get a successful video. Practice, rehearse and shoot multiple times, and send us only the best attempt.
* Pay particular attention to where the characters are and what they do in the shot. Get the timing and motion as accurate to the original shot as possible.
* Your video should be submitted as a .mp4 video if possible, although other video formats are allowed.

You can read more about the original film on Wikipedia: https://en.wikipedia.org/wiki/Modern_Times_%28film%29
You can torrent the movie for free (requires a torrent client): http://mtor.tv/charlie-chaplin-modern-times-1936-785.html

### Notes
#### shotdetect args
-i: set path to input file

-o: set path to output directory

-s : set threshold
The threshold is the level for shot detection. High will not detect a lot, low will detect a lot of false shots. A good choice is about 60.

-w : generates audio xml information. See the generated file for more details

-v : generates video xml informations. See the generated file for more details

-f : generates the first image of shots

-l : generates the last image of shots

-m : generates the thumbnails images

-r : generates the real size images

#### mechanical_chop args
-i : set path to input video file

-o : set path to output file. example: `./chop` will result in `./chop/out0000.mp4, out0001.mp4, out0002.mp4...`

-x : set path to `results.xml` from shotdetect step.
