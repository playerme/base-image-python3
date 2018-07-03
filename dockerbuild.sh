#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

# Update package index
echo "http://dl-cdn.alpinelinux.org/alpine/v3.7/main/" > /etc/apk/repositories 
echo "http://dl-cdn.alpinelinux.org/alpine/v3.7/community/" >> /etc/apk/repositories 
apk update 

# Install Python, pip, setuptools and bind aliases
# Python from Alpine repo is smaller vs. official Docker image
apk add python3=3.6.3-r9
python3 -m ensurepip 
pip3 install --upgrade pip setuptools 

if [ ! -e /usr/bin/pip ]
  then ln -s pip3 /usr/bin/pip 
fi 

if [[ ! -e /usr/bin/python ]]
  then ln -sf /usr/bin/python3 /usr/bin/python
fi 

# Build dependencies for Python packages
apk add \
    --virtual=.shared-build-dependencies \
    file binutils musl-dev \
    python3-dev=3.6.3-r9

apk add \
    --virtual=.scipy-build-dependencies \
    g++ gfortran openblas-dev

apk add \
    --virtual=.scipy-runtime-dependencies \
    libstdc++ openblas
    
# Numpy compilation requires xlocale.h
ln -s locale.h /usr/include/xlocale.h   

# Download, build, install Python packages
pip install --no-cache-dir numpy scipy pandas

rm /usr/include/xlocale.h 

# Cleanup, reduce image size
# remove unit tests, strip symbols
find /usr/lib/python3.*/ -name 'tests' -exec rm -r '{}' + 
find /usr/lib/python3.*/site-packages/ -name '*.so' -print -exec sh -c 'file "{}" | grep -q "not stripped" && strip -s "{}"' \;

apk del .scipy-build-dependencies 
apk del .shared-build-dependencies

rm -rf /root/.cache/* 
rm -rf /var/cache/apk/*