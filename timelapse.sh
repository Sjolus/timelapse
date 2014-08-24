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
if [ "$#" -eq 0 ]; then
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

mkdir -p $TMPDIR
mkdir -p $VIDDIR
mkdir -p $IMGDIR

echo "$(date) - Initiating Timelapse run" >> $LOGFILE
echo "$(date) - wget and jpegoptim-run" >> $LOGFILE
wget -nv $WGETTHIS -O $FILE &>> $LOGFILE
jpegoptim --quiet --max=50 $FILE >> $LOGFILE

echo "$(date) - Compiling list of images to use" >> $LOGFILE
AGEARGUMENT=${2:-}
if [ -z $AGEARGUMENT ]; then
	AGE=3
elif [ "$AGEARGUMENT" -eq "$AGEARGUMENT" ] 2>/dev/null; then
	AGE=$AGEARGUMENT
else
	echo"$(date) - Age argument poorly specified ($AGEARGUMENT). Setting to 3 days"
	AGE=3	
fi
echo "$(date) - Including all files newer than $AGE days of non-0 size." >> $LOGFILE
TIMELAPSEFILES=$(find $BASEIMGDIR -type f -size +1k -mtime -$AGE | sort)

echo "$(date) - Starting timelapse-creation" >> $LOGFILE
echo "$(date) - Cropping images if too large" >> $LOGFILE

count=0
for IMG in $TIMELAPSEFILES; do
        NEW=$(printf "FRAME_%05d.jpg" $count)
        let count=$count+1
        convert -size 1280x960+0+0 -gravity center $IMG $TMPDIR/$NEW
done

WEBM="$VIDDIR/timelapse.webm"
MP4="$VIDDIR/timelapse.mp4"

echo "$(date) - Image conversion completed. Compiling movies" >> $LOGFILE
echo "$(date) - 1st pass webm" >> $LOGFILE
avconv -i $TMPDIR/FRAME_%05d.jpg -loglevel error -threads 1 -s 1920x1080 -preset libvpx-1080p -b 4800k -pass 1 -an -f webm -y "$WEBM.tmp" >> $LOGFILE 2>&1
echo "$(date) - 2nd pass webm" >> $LOGFILE
avconv -i $TMPDIR/FRAME_%05d.jpg -loglevel error -threads 1 -preset libvpx-1080p -b 4800k -pass 2 -an -f webm -y "$WEBM.tmp" >> $LOGFILE 2>&1
echo "$(date) - webm to mp4" >> $LOGFILE
avconv -i $WEBM.tmp -loglevel error -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -b 2048k -r 30 -c:a libmp3lame -f mp4 -y "$MP4.tmp" >> $LOGFILE 2>&1

echo "$(date) - Moving temporary files to right places" >> $LOGFILE
mv $WEBM.tmp $WEBM
mv $MP4.tmp $MP4

echo "$(date) - Movie creation completed, removing TMPDIR" >> $LOGFILE
rm -rf $TMPDIR

echo "$(date) - Timelapse run completed" >> $LOGFILE
