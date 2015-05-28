#!/bin/bash

set -e

yum --assumeyes install ruby-devel \
                        gcc \
                        wget \
                        rpm-build \
                        gcc-c++ \
                        pkgconfig \
                        ncurses-devel \
                        openssl-devel \
                        readline-devel \
                        zlib-devel \
                        kernel-devel \
                        kernel-headers \
                        doxygen \
                        graphviz \
                        openssl-devel \
                        valgrind \
                        ruby-rdoc \
                        make \
                        zip

