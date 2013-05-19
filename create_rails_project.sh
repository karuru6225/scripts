#!/bin/bash

tmp_dir='/tmp/rails_tmp'
echo ""

if [ $# -ne 1 ];then
	echo "USAGE: $0 project_path"
	exit
fi

set -e

rm -rf ${tmp_dir}
mkdir ${tmp_dir}
cd ${tmp_dir}
cat > Gemfile << EOS
source "http://rubygems.org"
gem "rails", "3.2.13"
EOS

bundle install --path vendor/bundle 2> /dev/null > /dev/null
bundle exec rails new "$1" -d mysql --skip-bundle 2> /dev/null > /dev/null
rm -rf ${tmp_dir} 

echo "Succeeded in creating rails project"
echo "Please execute \"bundle install --path vendor/bundle\" on $1"

