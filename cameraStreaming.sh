#!/bin/bash

INPUT="/dev/video0"
if [ $# -ge 1 ];then
	INPUT="$1"
fi

modprobe snd-pcm-oss
ffserver -f /etc/ffserver.conf > ffserver.log 2>&1 & FFSERVER_PID=$!
#ffmpeg -f video4linux2 -s 640x480 -r 2 -i /dev/video0 http://localhost:8090/feed1.ffm
#ffmpeg -f video4linux2 -s 1024x768 -r 2 -i /dev/video0 http://localhost:8090/feed1.ffm
ffmpeg -f video4linux2 -s 1280x960 -r 2 -i /dev/video0 http://localhost:8090/feed1.ffm

kill -s TERM ${FFSERVER_PID}

