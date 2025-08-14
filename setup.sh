#!/bin/sh
set -e

# download and unpack LZ4 v1.10.0
wget -O lz4.tar.gz https://codeload.github.com/lz4/lz4/tar.gz/refs/tags/v1.10.0
tar xf lz4.tar.gz && rm lz4.tar.gz
mv lz4-1.10.0 lz4

make -C lz4 -j
make -C lz4 install PREFIX=/os

cp lz4/examples/fileCompress.c ./fileCompress.c

echo "LZ4 setup complete."