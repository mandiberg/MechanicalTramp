#!/usr/bin/python

# mechanical_chop.py
# Thomas Storey June 2015, Revised July 2015 to add tiny video removal
# This script takes a results xml file from shotdetect and a video file
# and outputs all the individual shots (as detected by shotdetect) as individual video files.
# it uses avconv to chop up the video.
# shotdetect: http://johmathe.name/shotdetect.html
# avconv: http://libav.org/avconv.html

# Example usage:
# ./mechanical_chop.py -i ModernTimes.mp4 -o ./chop -x ./shotdetect_out/results.xml

import argparse
import subprocess
import xml.etree.ElementTree as ET
import os

#parse arguments
parser = argparse.ArgumentParser(description='This script takes a results xml file from shotdetect and a video file\nand outputs all the individual shots (as detected by shotdetect) as individual video files.')
parser.add_argument('-i', '--input', help='Input video filepath',required=True)
parser.add_argument('-o', '--output', help='Output video directory',required=True)
parser.add_argument('-x', '--xml', help='Input xml filepath',required=True)
args = parser.parse_args()

#parse specified xml file, get "shots" element
tree = ET.parse(args.xml)
shotdetect = tree.getroot()
content = shotdetect.find("content")
body = content.find("body")
shots = body[0]

#chop video into shots
i = 0
for shot in shots:
    ss = int(shot.attrib['msbegin'])/float(1000)
    t = int(shot.attrib['msduration'])/float(1000)
    cmd = "avconv -ss %f -i %s -codec copy -t %f %s/out%04d.mp4" % (ss, args.input, t, args.output, i)
    cmd = cmd.split(" ")
    subprocess.call(cmd)
    i+=1
# delete tiny error videos (less than one second long)
# tiny videos are generated more often the higher the shotdetect sensitivity
# they are unlikely to be useful for our turkers, so we remove them
shotfiles = os.listdir(args.output)
print "found " + str(len(shotfiles)) + " videos"
i = 0
if(len(shotfiles) > 0):
    for file in sorted(shotfiles):
        cmd = "ffprobe -i %s -show_entries format=duration -v quiet -of csv='p=0'" % (args.output+"/"+file)
        shotlength = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
        print file + " is " + shotlength + " seconds long"
        if float(shotlength) < 1.0:
            print "deleting " + args.output+"/"+file + " because it is too short to be useful"
            os.remove(args.output+"/"+file)
            i+=1
    print "deleted " + str(i) + " shots total"
    if(i > 0):
        # need to rename the files so they are in order with no gaps
        # first, get the new list of files
        shotfiles = os.listdir(args.output)
        i = 0
        prefix = "out"
        extension = ".mp4"
        for file in sorted(shotfiles):
            newfile = "%s%04d%s" % (prefix, i, extension)
            print "renaming " + file + " -> " + newfile
            os.rename(args.output+"/"+file, args.output+"/"+newfile)
            i+=1
