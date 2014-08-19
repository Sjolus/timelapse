#!/bin/bash
set -o nounset
set -o errexit


# necessary declarations
BASEDIR=$(dirname $0)
DATE=$(date +%Y_%m_%d-%H_%M_%S)
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

# Load specified config if it exists and check for project and url after loading it
if [ "$#" -ne 1 ]; then
	echo "No config file argument found"
	exit 2
fi

PROJECT="$1"
CONFIG="$BASEDIR/$PROJECT.conf"


if [ -f $CONFIG ]; then
	source $CONFIG
else
	echo "Configuration file ($CONFIG) not found"
	exit 2
fi

BASEDIR="$TIMELAPSEPATH/$PROJECT"
TMPDIR="$BASEDIR/tmp"
BASEIMGDIR="$BASEDIR/img"
IMGDIR="$BASEIMGDIR/$YEAR/$MONTH/$DAY"
VIDDIR="$BASEDIR/video"
FILE="$IMGDIR/$DATE.jpg"
WGETTHIS="$(echo $URL)"
LOGFILE="$BASEDIR/$PROJECT.log"

echo "$(date) - Initiating Timelapse run" >> $LOGFILE

mkdir -p $TMPDIR
mkdir -p $VIDDIR
mkdir -p $IMGDIR

echo "$(date) - Sleeping before wget and jpegoptim-run" >> $LOGFILE
sleep 15
wget -nv $WGETTHIS -O $FILE &>> $LOGFILE
jpegoptim --quiet --max=50 $FILE > /dev/null 2>&1

echo "$(date) - Compiling list of images to use" >> $LOGFILE
TIMELAPSEFILES=$(find $BASEIMGDIR -type f | sort)

echo "$(date) - Starting timelapse-creation" >> $LOGFILE
count=0
for IMG in $TIMELAPSEFILES; do
        NEW=$(printf "FRAME_%05d.jpg" $count)
        let count=$count+1
        convert -crop 1280x960+0+0 -gravity center $IMG $TMPDIR/$NEW
done

WEBM="$VIDDIR/timelapse.webm"
MP4="$VIDDIR/timelapse.mp4"

echo "$(date) - Image conversion completed. Compiling movies" >> $LOGFILE

avconv -i $TMPDIR/FRAME_%05d.jpg -threads 1 -s 1920x1080 -preset libvpx-1080p -b 4800k -pass 1 -an -f webm -y "$WEBM" > /dev/null 2>&1
avconv -i $TMPDIR/FRAME_%05d.jpg -threads 1 -preset libvpx-1080p -b 4800k -pass 2 -an -f webm -y "$WEBM" > /dev/null 2>&1
avconv -i $WEBM -b 2048k -r 30 -c:a libmp3lame -y "$MP4" > /dev/null 2>&1

echo "$(date) - Movie creation completed, removing TMPDIR" >> $LOGFILE

rm -rf $TMPDIR

echo "$(date) - Timelapse run completed" >> $LOGFILE
