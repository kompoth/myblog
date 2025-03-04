#!/bin/bash

date=`date --iso-8601`

git add . && git commit -m "Update ${date}" && git push

hugo --minify

scp -r public myblog:~
