# HLS/DASH Local Testing with FFMPEG

To create a test raw video with FFMPEG:

```
ffmpeg -f lavfi -i testsrc=duration=60:size=1280x720:rate=30 \
       -f lavfi -i "sine=frequency=500:duration=60,volume=-15dB" \
       -c:v libx264 -c:a aac h264_aac_720p_30fps.mp4
```     

This create a 60s 720p video encoded in H264/AVC with AAC audio wrapped in an mp4 container.


We will now create MP4 chunks (.m4s), a DASH manifest (.mpd), and an HLS master playlist (.m3u8).
Each mp4 chunk has H264 video encoding and AAC audio encoding.


```
ffmpeg -i h264_aac_720p_30fps.mp4 \
  -map 0:v:0 -map 0:a:0 \
  -c:v libx264 -c:a aac -b:v 2500k -b:a 128k \
  -f dash \
  -hls_playlist 1 -hls_master_name master.m3u8 \
  -use_template 1 -use_timeline 1 \
  -seg_duration 4 \
  -init_seg_name 'init_$RepresentationID$.mp4' \
  -media_seg_name 'chunk_$RepresentationID$_$Number$.m4s' \
  manifest.mpd
```

Navigate to the directory containing your .mpd or .m3u8 files and spin up a CORS-compliant server:

```
npx http-server --cors="*" -p 8000
```

Verify the server is running:

```
http://localhost:8000/manifest.mpd
```

Should download the manifest file.

Open a browser tab and go to the Shaka Player Demo: shaka-player-demo.appspot.com

Click CUSTOM CONTENT

Add the URL to your .mpd or .m3u8.

```
http://localhost:8000/manifest.mpd
```
or
```
http://localhost:8000/master.m3u8
```