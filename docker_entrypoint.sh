#!/bin/bash

cd /workspace

git config --global user.email "user@email.com"
git config --global user.name "name"

# enable ssh
eval `ssh-agent -s`
