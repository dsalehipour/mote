#!/bin/sh
# A marketing motion study made from finished screenshot artwork.
# This is not a recorded App Store app preview; keep it separate from submission assets.
set -eu
cd "$(dirname "$0")"
ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -t 5.4 -i exports/01-copy-the-uncopyable.png \
  -loop 1 -t 5.4 -i exports/02-image-to-text.png \
  -loop 1 -t 5.4 -i exports/03-one-shortcut.png \
  -loop 1 -t 5.4 -i exports/04-on-your-mac.png \
  -filter_complex "[0:v]scale=1728:1080,pad=1920:1080:96:0:color=0xf7f6f2,setsar=1,fps=30,format=yuv420p[v0];[1:v]scale=1728:1080,pad=1920:1080:96:0:color=0xf7f6f2,setsar=1,fps=30,format=yuv420p[v1];[2:v]scale=1728:1080,pad=1920:1080:96:0:color=0xf7f6f2,setsar=1,fps=30,format=yuv420p[v2];[3:v]scale=1728:1080,pad=1920:1080:96:0:color=0xf7f6f2,setsar=1,fps=30,format=yuv420p[v3];[v0][v1]xfade=transition=fade:duration=0.45:offset=4.95[a];[a][v2]xfade=transition=fade:duration=0.45:offset=9.9[b];[b][v3]xfade=transition=fade:duration=0.45:offset=14.85[out]" \
  -map '[out]' -an -pix_fmt yuv420p -c:v libx264 -preset medium -crf 18 -profile:v high -level 4.0 -movflags +faststart exports/pluck-motion-study.mp4
