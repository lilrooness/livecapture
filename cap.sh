#!bin/bash

ffmpeg \
  -video_size 1280x1024 -framerate 25 -f x11grab -i :99 \
    -map 0:0 \
    -pix_fmt yuv420p \
      -c:v libvpx-vp9 -s 1280x1024 -keyint_min 60 -g 60 -speed 6 -tile-columns 4 -frame-parallel 1 -threads 8 -static-thresh 0 -max-intra-rate 300 -deadline realtime -lag-in-frames 0 -error-resilient 1 \
      -b:v 3000k \
        -f webm_chunk \
    -header "www/screencast_360.hdr" \
        -chunk_start_index 1 \
  www/screencast_360_%d.chk > ffmpeg_stream.log 2>&1 &





