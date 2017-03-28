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

function process_dda_reply {
  local readfile=""
  local writefile=""
  local content=""
  
  while read -r line
  do
   if [[ "$line" =~ ^ReadFilename=.* ]]; then
     readfile="${line##ReadFilename=}"
   fi
   if [[ "$line" =~ ^WriteFilename=.* ]]; then
     writefile="${line##WriteFilename=}"
   fi
   if [[ "$line" =~ ^ContentToWrite=.* ]]; then
     content="${line##ContentToWrite=}"
   fi
   if [[ "$line" == "EndMessage" ]]; then
     echo -n "$content" >"$writefile"
     cat "$readfile"
     break
   fi
  done
}

function process_dda_complete {
  while read -r line
  do
   if [[ "$line" =~ ^ReadDirectoryAllowed=.* ]]; then
     if [[ "false" == "${line##ReadDirectoryAllowed=}" ]]; then
       echo "Did not get read permission"
       exit
     fi 
   fi
   if [[ "$line" =~ ^WriteDirectoryAllowed=.* ]]; then
     if [[ "false" == "${line##WriteDirectoryAllowed=}" ]]; then
       echo "Did not get write permission"
       exit
     fi 
   fi
   if [[ "$line" == "EndMessage" ]]; then
     break
   fi
  done
}

function handle_progress {
  local total=0
  local succeeded=0
  local required=0
  local final=""
  
  while read -r line
  do
   if [[ "$line" =~ ^Total=.* ]]; then
     total="${line##Total=}"
   fi
   if [[ "$line" =~ ^Required=.* ]]; then
     required="${line##Required=}"
   fi
   if [[ "$line" == "FinalizedTotal=true" ]]; then
     final="final"
   fi
   if [[ "$line" =~ ^Succeeded=.* ]]; then
     succeeded="${line##Succeeded=}"
   fi
   if [[ "$line" == "EndMessage" ]]; then
     echo "Progress: retrieved $succeeded out of $required required and $total total ($final)"
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


exec 3<>/dev/tcp/127.0.0.1/9481

cat >&3 <<HERE
ClientHello
Name=My Client Name
ExpectedVersion=2.0
EndMessage
HERE

wait_for "NodeHello" <&3
wait_for "EndMessage" <&3

cat >&3 <<HERE
TestDDARequest
Directory=/tmp/
WantWriteDirectory=true
WantReadDirectory=true
EndMessage
HERE

wait_for "TestDDAReply" <&3
content=$(process_dda_reply <&3)

cat >&3 <<HERE
TestDDAResponse
Directory=/tmp/
ReadContent=$content
EndMessage
HERE

wait_for "TestDDAComplete" <&3
process_dda_complete <&3

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
Filename=$file
UploadFrom=disk
EndMessage
HERE

wait_with_progress "PutSuccessful" <&3
uri=$(get_uri <&3)
wait_for "EndMessage" <&3

exec 3<&-
exec 3>&-

echo URI: "$uri"


