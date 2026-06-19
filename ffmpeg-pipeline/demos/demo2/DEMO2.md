# HLS/DASH Local Testing with FFMPEG

Transcodes / ABR Ladder:

**1080p (1920x1080)**

* **AVC (H.264):** 4.5 Mbps (4500 kbps)
* **VP9 (~35% savings):** 3.0 Mbps (3000 kbps)
* **AV1 (~50% savings):** 2.2 Mbps (2200 kbps)

**720p (1280x720)**

* **AVC (H.264):** 2.5 Mbps (2500 kbps)
* **VP9 (~35% savings):** 1.6 Mbps (1600 kbps)
* **AV1 (~50% savings):** 1.2 Mbps (1200 kbps)

**480p (854x480)**

* **AVC (H.264):** 1.2 Mbps (1200 kbps)
* **VP9 (~35% savings):** 800 kbps
* **AV1 (~50% savings):** 600 kbps

**360p (640x360)**

* **AVC (H.264):** 700 kbps
* **VP9 (~35% savings):** 450 kbps
* **AV1 (~50% savings):** 350 kbps

- 
To create a test raw video with FFMPEG:

```
ffmpeg -f lavfi -i testsrc=duration=60:size=1280x720:rate=30 \
       -f lavfi -i "sine=frequency=500:duration=60,volume=-15dB" \
       -c:v libx264 -c:a aac h264_aac_720p_30fps.mp4
```     

This create a 60s 720p video encoded in H264/AVC with AAC audio wrapped in an mp4 container.

```
sh transcode.sh
```

This will create the ABR ladder. It will convert the video into 12 different videos with diffferent codecs, resolutions and bitrates and mentioned above.

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