#!/bin/bash

# CloudForms Get Services - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"
totalRequests=10 # Total number of requests
groupCount=5 # Number to order at one time
groupWait=1 # Minutes between groups
apiWait=3 # Seconds between API calls in a group

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -i <item name> -u <username> [ -w <uri> ]"
}

while getopts nu:c:i:t:g:p:a:w:d: FLAG; do
  case $FLAG in
    n) noni=1;;
    u) username="$OPTARG";;
    i) itemName="$OPTARG";;
    w) uri="$OPTARG";;
    *) usage;exit;;
    esac
done

if [ -z "$itemName" ]
then
  usage
  exit 1
fi

if [ -z "$username" ]
then
  echo -n "Enter CF Username: ";read username
fi

echo -n "Enter CF Password: "
stty -echo
read password
stty echo
echo


tok=`curl -s --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth|python -m json.tool|grep auth_token|cut -f4 -d\"`
#echo "tok is $tok"
itemName=`echo $itemName|sed "s/ /_/g"`
itemName=`echo $itemName|cut -c1-30`

curl -s -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET $uri/api/services?attributes=name\&expand=resources|python -m json.tool|grep '"name"'|cut -f2 -d:|grep $itemName|grep $username|sed -e 's/[ |"]//g'
