#!/bin/bash

set -o errexit

apt-get -q update
apt-get install -y python libasound2-dev
