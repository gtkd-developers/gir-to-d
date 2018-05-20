#!/usr/bin/env python3

# Creates a temporary girtod binary that we can run in Meson's configure phase
# in order to get a list of the generated source files in advance.

import os
import sys
import subprocess

meson_build_root = os.environ.get('MESON_BUILD_ROOT')
meson_source_root = os.environ.get('MESON_SOURCE_ROOT')

if not meson_build_root or not meson_source_root:
    print('This script should only be run by the Meson build system.')
    sys.exit(1)


# This is an epic hack, but it ensures that we build both the library and girtod itself with the right
# compiler flags.
# We can not use Meson's normal generator helper, because we do not know the files girtod generates in advance.

temp_build_dir = os.path.join(meson_build_root, 'tmp_girtod')
os.makedirs(temp_build_dir, exist_ok=True)

os.chdir(temp_build_dir)

meson_cmd = ['meson',
             '--buildtype=debugoptimized',
             '-Dbuild-glibd=false',
             os.path.relpath(meson_source_root, temp_build_dir)]

# configure
subprocess.run(meson_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

# make
subprocess.run('ninja', check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
