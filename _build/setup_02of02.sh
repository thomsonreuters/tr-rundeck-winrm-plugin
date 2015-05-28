#!/bin/bash

set -e

yum --assumeyes install rubygems \
                        gdbm-devel \
                        libffi-devel \
                        valgrind-devel \
                        libyaml-devel

yum --assumeyes remove tk-devel

gem install --no-rdoc --no-ri fpm

useradd packager
