#!/usr/bin/env python3

import os
import sys
import glob
import subprocess

meson_build_root = os.environ.get('MESON_BUILD_ROOT')
meson_source_root = os.environ.get('MESON_SOURCE_ROOT')

if not meson_build_root or not meson_source_root:
    print('This script should only be run by the Meson build system.')
    sys.exit(1)

if len(sys.argv) != 2:
    print('Invalid number of arguments: Need only the path to wrap files.')
    sys.exit(1)

girtod_binary = os.path.join(meson_build_root, 'tmp_girtod', 'girtod')
sources_dir = os.path.join(meson_build_root, 'wrap.gen', 'glibd')
os.makedirs(sources_dir, exist_ok=True)

girtod_cmd = [girtod_binary,
             '-i', sys.argv[1],
             '-o', sources_dir]

# generate bindings
subprocess.run(girtod_cmd, check=True)

files = glob.glob(os.path.join(sources_dir, '**', '*.d'), recursive=True)
for fname in sorted(files):
    # newer versions of Meson (>= 0.43) don't like absolute paths
    print(os.path.relpath(fname, meson_source_root))
