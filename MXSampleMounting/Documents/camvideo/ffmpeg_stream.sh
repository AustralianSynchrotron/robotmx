#!/bin/sh
ffmpeg -i http://10.109.2.135/mpeg4 -vf "drawtext=textfile=/home/gautam/a.txt:reload=1:y=h-7*line_h:fontfile=/usr/share/fonts/truetype/freefont/FreeSansBold.ttf:fontcolor=yellow:fontsize=15" -vcodec libx264 -r 9 -b 150k -f mpegts udp://0.0.0.0:5900
