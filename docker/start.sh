#!/bin/bash

if [ -d "catalogs/bin" ]
then
  echo "bin directory exists, skipping"
else
  mkdir catalogs/bin
fi

if [ -d "interchange/lib" ]
then
  echo "interchange lib directory exists, skipping build."
else
  cd interchange-src
  cp docker/Makefile ./
  cp docker/initp.pl ./scripts/
  make && make install
  cd ../interchange
  cp interchange.cfg.dist interchange.cfg
  bin/compile_link
  cd ..
fi

if [ -d "catalogs/demo" ]
then
  echo "demo catalog directory exists, skipping makecat."
else
  cd interchange && bin/makecat -F --catalogname=demo --basedir=/home/interchange/catalogs --cgibase=/ --documentroot=/home/interchange/catalogs/static --interchangegroup=interchange --interchangeuser=interchange --vendroot=/home/interchange/interchange --homedir=/home/interchange --catroot=/home/interchange/catalogs/demo --cgidir=/home/interchange/catalogs/bin --servername=localhost:4242 --cgiurl=/demo --demotype=strap --mailorderto=interchange --imagedir=/home/interchange/catalogs/static/images --samplehtml=/home/interchange/catalogs/static
  cd ../catalogs/demo && sh config/add_global_usertag
  cd ../static && ln -s ./ demo
  cd ../../ && cp interchange-src/docker/variable.txt catalogs/demo/products/
  interchange/bin/interchange
fi

if [ -f "catalogs/app.psgi" ]
then
  echo "app.psgi file exists, skipping copy."
else
  cp interchange-src/docker/app.psgi catalogs/
fi

plackup -s Starman catalogs/app.psgi

