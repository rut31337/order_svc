#!/bin/bash

# CloudForms OrderGanza - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"
totalRequests=10 # Total number of requests
groupCount=5 # Number to order at one time
groupWait=1 # Minutes between groups
apiWait=3 # Seconds between API calls in a group

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -c <catalog name> -i <item name> [ -u <username> -t <totalRequests> -g <groupCount> -p <groupWait> -a <apiWait> -w <uri> -d <key1=value;key2=value> -n ]"
}

while getopts nu:c:i:t:g:p:a:w:d: FLAG; do
  case $FLAG in
    n) noni=1;;
    u) username="$OPTARG";;
    c) catalogName="$OPTARG";;
    i) itemName="$OPTARG";;
    t) totalRequests="$OPTARG";;
    g) groupCount="$OPTARG";;
    p) groupWait="$OPTARG";;
    a) apiWait="$OPTARG";;
    w) uri="$OPTARG";;
    d) keypairs="$OPTARG";;
    *) usage;exit;;
    esac
done

if [ -z "$catalogName" -o -z "$itemName" ]
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
catalogName=`echo $catalogName|sed "s/ /+/g"`
itemName=`echo $itemName|sed "s/ /+/g"`
catalogID=`curl -s -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs?attributes=name,id&expand=resources&filter%5B%5D=name%3D$catalogName" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,]//g"`
echo "catalogID is $catalogID"
itemID=`curl -s -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_templates?attributes=service_template_catalog_id,id,name&expand=resources&filter%5B%5D=name=$itemName&filter%5B%5D=service_template_catalog_id%3D$catalogID" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,]//g"`
echo "itemID is $itemID"

if [ "$noni" != 1 ]
then
  echo -n "Are you sure you wish to deploy $totalRequests instances of this catalog item? (y/N): ";read yn
  if [ "$yn" != "y" ]
  then
    echo "Exiting."
    exit
  fi
fi

KPS=""
if [ -n "$keypairs" ]
then
  IFS=";"
  for kp in $keypairs
  do
    k=`echo $kp|cut -f1 -d=`
    v=`echo $kp|cut -f2 -d=`
    KPS="${KPS}, \"${k}\" : \"${v}\""
  done
fi

PAYLOAD="{ \"action\": \"order\", \"resource\": { \"href\": \"https://$uri/api/service_templates/$itemID\"${KPS} } }"
((slp=$groupWait * 60))
#echo "PAYLOAD Is ${PAYLOAD}"
t=1
g=1
while [ $t -le $totalRequests ]
do
  c=1
  tok=`curl -s --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth|python -m json.tool|grep auth_token|cut -f4 -d\"`
  while [ $c -le $groupCount -a $t -le $totalRequests ]
  do
    echo "Deploying request $t in group $g"
    curl -s -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X POST $uri/api/service_catalogs/$catalogID/service_templates -d "$PAYLOAD" | python -m json.tool
    (( c = $c + 1 ))
    (( t = $t + 1 ))
    sleep $apiWait
  done
  if [ $t -le $totalRequests ]
  then
    echo "Sleeping $slp seconds..."
    (( g = $g + 1 ))
    sleep $slp
  fi
done
