Xvfb :99 -screen 0 1600x1200x24 &
DISPLAY=:99 firefox &
# ffmpeg -video_size 1024x768 -framerate 25 -f x11grab -i :99.0+100,200 output.mp4
# ffmpeg -video_size 1280x1024 -framerate 25 -f x11grab -i :99 output.mp4

( cd www ; python3 -m http.server 8000 > ../python_webserver.log 2>&1 &)


