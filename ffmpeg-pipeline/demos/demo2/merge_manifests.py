#!/usr/bin/env python3
"""
merge_manifests.py

Merges multi-codec HLS and DASH manifests from h264/, vp9/, av1/ directories
into a unified master.m3u8 and master.mpd at the current directory level.

Usage: python3 merge_manifests.py
"""

import re
import xml.etree.ElementTree as ET
from pathlib import Path

CODECS = ['h264', 'vp9', 'av1']
DASH_NS = 'urn:mpeg:dash:schema:mpd:2011'


def tag(name):
    return f'{{{DASH_NS}}}{name}'


# ── HLS ───────────────────────────────────────────────────────────────────────

def parse_hls_master(path):
    """Returns (media_lines, stream_pairs) from an HLS master playlist."""
    lines = Path(path).read_text().splitlines()
    media_lines, streams = [], []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('#EXT-X-MEDIA'):
            media_lines.append(line)
        elif line.startswith('#EXT-X-STREAM-INF'):
            uri = lines[i + 1] if i + 1 < len(lines) else ''
            streams.append((line, uri))
            i += 1
        i += 1
    return media_lines, streams


def prefix_uri_attr(line, prefix):
    """Rewrite URI="..." inside a tag line to include a directory prefix."""
    return re.sub(r'URI="([^"]+)"', lambda m: f'URI="{prefix}/{m.group(1)}"', line)


def merge_hls(output='master.m3u8'):
    out = ['#EXTM3U', '#EXT-X-VERSION:6', '#EXT-X-INDEPENDENT-SEGMENTS', '']

    # Single audio rendition from h264 only
    h264_media, _ = parse_hls_master('h264/master.m3u8')
    for line in h264_media:
        if 'TYPE=AUDIO' in line:
            out.append(prefix_uri_attr(line, 'h264'))
    out.append('')

    # Video streams from all codecs, URI prefixed with codec directory
    for codec in CODECS:
        _, streams = parse_hls_master(f'{codec}/master.m3u8')
        for inf, uri in streams:
            out.append(inf)
            out.append(f'{codec}/{uri}')
        out.append('')

    Path(output).write_text('\n'.join(out))
    print(f'Written: {output}')


def patch_media_playlists():
    """Insert #EXT-X-INDEPENDENT-SEGMENTS into each variant media playlist."""
    inserted = 0
    for codec in CODECS:
        for playlist in sorted(Path(codec).glob('media_*.m3u8')):
            text = playlist.read_text()
            if '#EXT-X-INDEPENDENT-SEGMENTS' in text:
                continue
            text = re.sub(
                r'(#EXT-X-VERSION:[^\n]+\n)',
                r'\1#EXT-X-INDEPENDENT-SEGMENTS\n',
                text, count=1
            )
            playlist.write_text(text)
            inserted += 1
    print(f'Patched {inserted} media playlists with #EXT-X-INDEPENDENT-SEGMENTS')


# ── DASH ──────────────────────────────────────────────────────────────────────

def register_namespaces():
    ET.register_namespace('', DASH_NS)
    ET.register_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
    ET.register_namespace('xlink', 'http://www.w3.org/1999/xlink')


def content_type(ads):
    """Determine AdaptationSet content type from attribute or Representation mimeType."""
    ct = ads.get('contentType')
    if ct:
        return ct
    rep = ads.find(tag('Representation'))
    if rep is not None:
        mime = rep.get('mimeType', '')
        if 'video' in mime:
            return 'video'
        if 'audio' in mime:
            return 'audio'
    return None


def prefix_segment_paths(ads, prefix):
    """Prefix initialization and media template paths with a codec directory."""
    for st in ads.iter(tag('SegmentTemplate')):
        for attr in ('initialization', 'media'):
            if attr in st.attrib:
                st.set(attr, f"{prefix}/{st.get(attr)}")


def load_mpd(path):
    tree = ET.parse(path)
    root = tree.getroot()
    period = root.find(tag('Period'))
    video = [a for a in period.findall(tag('AdaptationSet')) if content_type(a) == 'video']
    audio = [a for a in period.findall(tag('AdaptationSet')) if content_type(a) == 'audio']
    return root, period, video, audio


def merge_mpd(output='master.mpd'):
    register_namespaces()

    data = {codec: load_mpd(f'{codec}/manifest.mpd') for codec in CODECS}

    # h264 MPD supplies the document-level attributes (duration, profiles, etc.)
    base_root, period, _, base_audio = data['h264']

    # Clear the period and repopulate in order
    for child in list(period):
        period.remove(child)

    next_id = 0

    # One video AdaptationSet per codec
    for codec in CODECS:
        _, _, video_sets, _ = data[codec]
        for ads in video_sets:
            prefix_segment_paths(ads, codec)
            ads.set('id', str(next_id))
            next_id += 1
            period.append(ads)

    # Single audio AdaptationSet from h264
    if base_audio:
        ads = base_audio[0]
        prefix_segment_paths(ads, 'h264')
        ads.set('id', str(next_id))
        period.append(ads)

    ET.ElementTree(base_root).write(output, xml_declaration=True, encoding='utf-8')
    print(f'Written: {output}')


if __name__ == '__main__':
    merge_hls()
    patch_media_playlists()
    merge_mpd()
