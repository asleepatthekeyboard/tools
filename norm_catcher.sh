#!/bin/bash

# go get the NYW video.  MORE NORM!

cd $HOME

VID=`lynx --dump http://www.newyankee.com/index.php?id=56 | grep asset | awk '{ print $2}; '`

# sometimes the web admin screws up and gets a space in the filename. 
# this unencodes the %xx

FNAME=`python -c "import sys, urllib as ul; print ul.unquote_plus(\"$VID\")" | cut -f 6 -d/`

#don't fetch if the file has alredy been fetched.

if [ ! -f "$FNAME" ];
then
  wget $VID
fi
