eval $(xdotool getmouselocation --shell)
sleep 1
IMAGE=`import -window root -depth 8 -crop 1x1+$X+$Y txt:-`
COLOR=`echo $IMAGE | grep -om1 '#\w\+'`
echo -n $COLOR | xclip -i -selection CLIPBOARD
echo "Color under mouse cursor 1 second ago: " $COLOR 
