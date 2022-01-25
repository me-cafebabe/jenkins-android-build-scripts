#!/bin/bash

MY_PATH=$(dirname $(realpath "$0"))

source $(find ${MY_PATH}/ -name '*.sh' ! -name 'init.sh' ! -name "$(basename $0)")
