#! /bin/bash
function wait_for {
  local line
  local str=$1
  while read -r line
  do
    if [ "$line" == "$str" ]; then
      break
    fi
  done
}

function handle_progress {
  local total=0
  local succeeded=0
  local final=""
  
  while read -r line
  do
   if [[ "$line" =~ ^Total=.* ]]; then
     total="${line##Total=}"
   fi
   if [[ "$line" == "FinalizedTotal=true" ]]; then
     final="final"
   fi
   if [[ "$line" =~ ^Succeeded=.* ]]; then
     succeeded="${line##Succeeded=}"
   fi
   if [[ "$line" == "EndMessage" ]]; then
     echo "Progress: inserted $succeeded out of $total ($final)"
     break
   fi
  done
}

function wait_with_progress {
  while read -r line
  do
    if [ "$line" == "SimpleProgress" ]; then
      handle_progress
    fi
    if [ "$line" == "$1" ]; then
      break
    fi
  done
}

function get_uri {
  local line
  while read -r line
  do
   if [[ "$line" =~ ^URI=.* ]]; then
     echo "${line##URI=}"
     break
   fi
  done
}


exec 3<>/dev/tcp/127.0.0.1/9481

cat >&3 <<HERE
ClientHello
Name=My Client Name
ExpectedVersion=2.0
EndMessage
HERE

wait_for "NodeHello" <&3
wait_for "EndMessage" <&3

file="$1"
size=$(stat -c%s "$file")
mime=$(file --mime-type "$file" |awk '{print $2}')

cat >&3 <<HERE
ClientPut
URI=CHK@
Metadata.ContentType=$mime
Identifier=1234
Verbosity=1
GetCHKOnly=false
TargetFilename=$(basename "$file")
DataLength=$size
UploadFrom=direct
Data
HERE

dd status=none if="$file" bs="$size" count=1 |pv -L 500k >&3

wait_with_progress "PutSuccessful" <&3
uri=$(get_uri <&3)
wait_for "EndMessage" <&3

exec 3<&-
exec 3>&-

echo URI: "$uri"

