#!/bin/bash

set -e

var_version="0.1.0"

var_ruby_version="2.0.0-p645"
var_pkg_maintner="dhruv.ahuja@thomsonreuters.com"

var_prefix="/opt/tr-rundeck-winrm-plugin"
var_rundeck_libext="/var/lib/rundeck/libext"
var_bin_path="/usr/local/bin"

var_bins=""

rm -rf ${var_prefix}
mkdir --parents ${var_prefix}
mkdir --parents ${var_rundeck_libext}

su --login packager --command="wget --timestamping http://cache.ruby-lang.org/pub/ruby/2.0/ruby-${var_ruby_version}.tar.gz"

su --login packager --command="tar zxf ruby-${var_ruby_version}.tar.gz"

su --login packager --command="cd ruby-${var_ruby_version} && ./configure --prefix=${var_prefix} --exec-prefix=${var_prefix} --enable-shared --disable-install-doc"
su --login packager --command="cd ruby-${var_ruby_version} && make"

chown -R packager:packager ${var_prefix}

su --login packager --command="cd ruby-${var_ruby_version} && make install"

su --login packager --command="export PATH=${var_prefix}/bin:${PATH} && gem install --no-document winrm-fs"

zip -9 -r tr-rundeck-winrm-plugin.zip src/

mv tr-rundeck-winrm-plugin.zip ${var_rundeck_libext}

for _file in ext/*; do var_bins="${var_bins} ${var_bin_path}/$(basename ${_file})"; done;

cp --archive ext/* ${var_bin_path}

chown -R root:root ${var_prefix}

chown -R root:root ${var_rundeck_libext}/tr-rundeck-winrm-plugin.zip

chown root:root ${var_bins}
chmod a+x ${var_bins}

cd rpm/

fpm -t rpm -s dir --name tr-rundeck-winrm-plugin --force --maintainer ${var_pkg_maintner} --version ${var_version} ${var_prefix} ${var_rundeck_libext}/tr-rundeck-winrm-plugin.zip ${var_bins}

cd -

rm -rf ${var_prefix}
rm -rf ${var_rundeck_libext}/tr-rundeck-winrm-plugin.zip
rm ${var_bins}
