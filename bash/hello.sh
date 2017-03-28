#! /bin/bash
function wait_for {
  local line
  local str=$1
  while read -r line
  do
    >&2 echo "$line"
    if [ "$line" == "$str" ]; then
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

exec 3<&-
exec 3>&-

