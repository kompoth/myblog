#!/bin/bash

date=`date --iso-8601`

git add . && git commit -m "Update ${date}" && git push

rm public/ -r
hugo --minify

ssh myblog -t 'rm public/* -r'
scp -r public myblog:~
