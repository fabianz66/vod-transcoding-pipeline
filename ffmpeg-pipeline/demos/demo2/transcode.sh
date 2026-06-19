#!/bin/bash

# ==============================================================================
# Multi-Codec ABR Transcoding Script (CMAF Edition)
# This script dynamically calculates keyframe intervals based on input FPS 
# and generates DASH and HLS manifests sharing .m4s chunks.
# ==============================================================================

INPUT_FILE="h264_aac_720p_30fps.mp4"

# ------------------------------------------------------------------------------
# 0. Dynamic Framerate & GOP Calculation
# ------------------------------------------------------------------------------
echo "Analyzing input video..."

# Extract framerate fraction (e.g., 24000/1001, 60/1, 30/1)
FPS_FRACTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

# Evaluate fraction and round to nearest integer using awk
FPS=$(awk "BEGIN {print int(($FPS_FRACTION) + 0.5)}")

# Define target segment length (in seconds)
SEG_DURATION=2

# Calculate GOP size (Keyframe interval)
GOP_SIZE=$((FPS * SEG_DURATION))

echo "Detected FPS: $FPS"
echo "Calculated GOP Size: $GOP_SIZE (for ${SEG_DURATION}s segments)"
echo "------------------------------------------------------------------------------"

# Create directories to prevent manifest collisions
mkdir -p h264 vp9 av1

# ------------------------------------------------------------------------------
# 1. H.264 (AVC) - Universal DASH & HLS
# ------------------------------------------------------------------------------
echo "Starting H.264 Transcoding..."

ffmpeg -y -i "$INPUT_FILE" \
-filter_complex \
"[0:v]format=yuv420p,split=4[v1][v2][v3][v4]; \
[v1]scale=-2:1080[v1out]; \
[v2]scale=-2:720[v2out]; \
[v3]scale=-2:480[v3out]; \
[v4]scale=-2:360[v4out]" \
-map "[v1out]" -c:v:0 libx264 -b:v:0 4500k -maxrate:v:0 4800k -bufsize:v:0 9000k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" -sc_threshold 0 -profile:v:0 main \
-map "[v2out]" -c:v:1 libx264 -b:v:1 2500k -maxrate:v:1 2700k -bufsize:v:1 5000k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" -sc_threshold 0 -profile:v:1 main \
-map "[v3out]" -c:v:2 libx264 -b:v:2 1200k -maxrate:v:2 1300k -bufsize:v:2 2400k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" -sc_threshold 0 -profile:v:2 main \
-map "[v4out]" -c:v:3 libx264 -b:v:3 700k  -maxrate:v:3 800k  -bufsize:v:3 1400k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" -sc_threshold 0 -profile:v:3 main \
-map a:0 -c:a aac -b:a 128k -ar 44100 \
-f dash -seg_duration "$SEG_DURATION" -use_timeline 1 -use_template 1 \
-dash_segment_type mp4 \
-window_size 0 \
-hls_playlist 1 -hls_master_name master.m3u8 \
-init_seg_name 'init_$RepresentationID$.m4s' \
-media_seg_name 'chunk_$RepresentationID$_$Number$.m4s' \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
h264/manifest.mpd

# ------------------------------------------------------------------------------
# 2. VP9 - Web Optimizer (~35% Savings)
# ------------------------------------------------------------------------------
echo "Starting VP9 Transcoding..."

ffmpeg -y -i "$INPUT_FILE" \
-filter_complex \
"[0:v]format=yuv420p,split=4[v1][v2][v3][v4]; \
[v1]scale=-2:1080[v1out]; \
[v2]scale=-2:720[v2out]; \
[v3]scale=-2:480[v3out]; \
[v4]scale=-2:360[v4out]" \
-map "[v1out]" -c:v:0 libvpx-vp9 -row-mt 1 -b:v:0 3000k -maxrate:v:0 3200k -bufsize:v:0 6000k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v2out]" -c:v:1 libvpx-vp9 -row-mt 1 -b:v:1 1600k -maxrate:v:1 1800k -bufsize:v:1 3200k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v3out]" -c:v:2 libvpx-vp9 -row-mt 1 -b:v:2 800k  -maxrate:v:2 900k  -bufsize:v:2 1600k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v4out]" -c:v:3 libvpx-vp9 -row-mt 1 -b:v:3 450k  -maxrate:v:3 500k  -bufsize:v:3 900k  -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map a:0 -c:a aac -b:a 128k -ar 44100 \
-f dash -seg_duration "$SEG_DURATION" -use_timeline 1 -use_template 1 \
-dash_segment_type mp4 \
-window_size 0 \
-hls_playlist 1 -hls_master_name master.m3u8 \
-init_seg_name 'init_$RepresentationID$.m4s' \
-media_seg_name 'chunk_$RepresentationID$_$Number$.m4s' \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
vp9/manifest.mpd

# ------------------------------------------------------------------------------
# 3. AV1 - The Next Generation (~50% Savings)
# ------------------------------------------------------------------------------
echo "Starting AV1 Transcoding..."

ffmpeg -y -i "$INPUT_FILE" \
-filter_complex \
"[0:v]format=yuv420p,split=4[v1][v2][v3][v4]; \
[v1]scale=-2:1080[v1out]; \
[v2]scale=-2:720[v2out]; \
[v3]scale=-2:480[v3out]; \
[v4]scale=-2:360[v4out]" \
-map "[v1out]" -c:v:0 libsvtav1 -preset 8 -b:v:0 2200k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v2out]" -c:v:1 libsvtav1 -preset 8 -b:v:1 1200k -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v3out]" -c:v:2 libsvtav1 -preset 8 -b:v:2 600k  -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map "[v4out]" -c:v:3 libsvtav1 -preset 8 -b:v:3 350k  -g "$GOP_SIZE" -keyint_min "$GOP_SIZE" \
-map a:0 -c:a aac -b:a 128k -ar 44100 \
-f dash -seg_duration "$SEG_DURATION" -use_timeline 1 -use_template 1 \
-dash_segment_type mp4 \
-window_size 0 \
-hls_playlist 1 -hls_master_name master.m3u8 \
-init_seg_name 'init_$RepresentationID$.m4s' \
-media_seg_name 'chunk_$RepresentationID$_$Number$.m4s' \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
av1/manifest.mpd

# ------------------------------------------------------------------------------
# 4. Create Multi-Codec Master Manifests (HLS)
# ------------------------------------------------------------------------------
echo "Stitching together Multi-Codec Master HLS Playlist..."

MASTER_HLS="master.m3u8"
echo "#EXTM3U" > "$MASTER_HLS"
echo "#EXT-X-VERSION:6" >> "$MASTER_HLS"

# Concatenate the variant streams from the three files, filtering out redundant headers
# We use 'sed' to prepend the directory path so the master playlist knows exactly where to look
grep -vE "^#EXTM3U|^#EXT-X-VERSION" h264/master.m3u8 | sed 's/media_/h264\/media_/g' >> "$MASTER_HLS"
grep -vE "^#EXTM3U|^#EXT-X-VERSION" vp9/master.m3u8 | sed 's/media_/vp9\/media_/g' >> "$MASTER_HLS"
grep -vE "^#EXTM3U|^#EXT-X-VERSION" av1/master.m3u8 | sed 's/media_/av1\/media_/g' >> "$MASTER_HLS"

echo "Multi-codec HLS master playlist created at: $MASTER_HLS"
echo "Note: DASH (.mpd) multi-codec merging requires XML parsing and is typically handled by Shaka Packager or Bento4."

echo "All ABR transcoding complete!"