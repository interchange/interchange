#!/bin/bash

ln -s /home/interchange/catalogs/interchange.cfg interchange/
mkdir catalogs/bin

if [ -d "catalogs/demo" ]
then
  echo "demo catalog directory exists, skipping makecat."
else
  cp interchange/interchange.cfg.dist catalogs/
  cd interchange && bin/makecat -F --catalogname=demo --basedir=/home/interchange/catalogs --cgibase=/ --documentroot=/home/interchange/catalogs/static --interchangegroup=interchange --interchangeuser=interchange --vendroot=/home/interchange/interchange --homedir=/home/interchange --catroot=/home/interchange/catalogs/demo --cgidir=/home/interchange/catalogs/bin --servername=localhost:4242 --cgiurl=/demo --demotype=strap --mailorderto=interchange --imagedir=/home/interchange/catalogs/static/images --samplehtml=/home/interchange/catalogs/static
  cd ../catalogs/demo && sh config/add_global_usertag
  cd ../static && ln -s ./ demo
  cd ../../ && cp interchange-src/docker/site.txt catalogs/demo/products/
fi

cp interchange-src/docker/app.psgi catalogs/app.psgi
plackup catalogs/app.psgi

