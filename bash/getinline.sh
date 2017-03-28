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

function get_data_length {
  local line
  while read -r line
  do
   if [[ "$line" =~ ^DataLength=.* ]]; then
     echo "${line##DataLength=}"
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
ClientGet
URI=CHK@otFYYKhLKFzkAKhEHWPzVAbzK9F3BRxLwuoLwkzefqA,AKn6KQE7c~8G5dLa4TuyfG16XIUwycWuFurNJYjbXu0,AAMC--8/example.txt
Identifier=1234
Verbosity=0
ReturnType=direct
EndMessage
HERE

wait_for "AllData" <&3
len=$(get_data_length <&3)
wait_for "Data" <&3
dd status=none bs="$len" count=1 <&3 >&2

exec 3<&-
exec 3>&-

