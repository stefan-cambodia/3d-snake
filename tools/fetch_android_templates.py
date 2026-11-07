#!/usr/bin/env python3
"""Fetch only the Android export templates out of the official Godot .tpz bundle.

The official export template bundle is a ~1.3 GB zip containing templates for
every platform. Android export only needs `version.txt`, `android_debug.apk`,
`android_release.apk` (and optionally `android_source.zip` for Gradle builds).

This script reads the remote zip through HTTP Range requests, so only the
central directory and the required members are downloaded (~10x less data).

Usage:
    fetch_android_templates.py <godot_version> <destination_dir> [--with-source]

Example:
    fetch_android_templates.py 4.7.2 tools/godot/editor_data/export_templates/4.7.2.stable
"""
import io
import os
import sys
import urllib.request
import zipfile

WANTED = ["version.txt", "android_debug.apk", "android_release.apk"]


class HttpRangeFile(io.RawIOBase):
    """Minimal seekable read-only file object backed by HTTP Range requests."""

    def __init__(self, url: str):
        super().__init__()
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req) as resp:
            self.url = resp.geturl()  # follow redirects once
            self.size = int(resp.headers["Content-Length"])
        self.pos = 0
        self.downloaded = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        elif whence == io.SEEK_END:
            self.pos = self.size + offset
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as resp:
            data = resp.read()
        self.pos += len(data)
        self.downloaded += len(data)
        return data

    def readinto(self, b):
        data = self.read(len(b))
        b[: len(data)] = data
        return len(data)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    version = sys.argv[1]
    dest = sys.argv[2]
    wanted = list(WANTED)
    if "--with-source" in sys.argv:
        wanted.append("android_source.zip")
    url = (
        f"https://github.com/godotengine/godot/releases/download/{version}-stable/"
        f"Godot_v{version}-stable_export_templates.tpz"
    )
    os.makedirs(dest, exist_ok=True)
    remote = HttpRangeFile(url)
    print(f"Remote bundle: {remote.size / 1e6:.1f} MB")
    # Buffer reads so zipfile's many small reads do not become many HTTP requests.
    buffered = io.BufferedReader(remote, buffer_size=4 * 1024 * 1024)
    with zipfile.ZipFile(buffered) as zf:
        names = {os.path.basename(n): n for n in zf.namelist()}
        for name in wanted:
            if name not in names:
                print(f"ERROR: {name} not found in bundle")
                sys.exit(2)
            info = zf.getinfo(names[name])
            print(f"  extracting {name} ({info.file_size / 1e6:.1f} MB)...", flush=True)
            out_path = os.path.join(dest, name)
            with zf.open(info) as src, open(out_path + ".part", "wb") as dst:
                while True:
                    chunk = src.read(1 << 20)
                    if not chunk:
                        break
                    dst.write(chunk)
            os.replace(out_path + ".part", out_path)
    print(f"Done. Downloaded {remote.downloaded / 1e6:.1f} MB instead of {remote.size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
