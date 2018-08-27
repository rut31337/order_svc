#!/bin/bash

IFS=";"

# CloudForms OrderGanza - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"
totalRequests=10 # Total number of requests
groupCount=5 # Number to order at one time
groupWait=1 # Minutes between groups
apiWait=3 # Seconds between API calls in a group

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -c <catalog name> -i <item name> [ -u <username> -P <password> -t <totalRequests> -g <groupCount> -p <groupWait> -a <apiWait> -w <uri> -d <key1=value;key2=value> -n -N]"
}

while getopts Nnu:P:c:i:t:g:p:a:w:d: FLAG; do
  case $FLAG in
    n) noni=1;;
    u) username="$OPTARG";;
    P) password="$OPTARG";;
    N) insecure=1;;
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

if [ -z "$password" ]
then
  echo -n "Enter CF Password: "
  stty -echo
  read password
  stty echo
  echo
fi

if [ "$insecure" == 1 ]
then
  ssl="-k"
else
  ssl=""
fi

tok=`curl -s $ssl --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth`
err=$?
tt=`echo $tok|grep error`
if [ $err != 0 -o -n "$tt" ]
then
  echo "ERROR: Authentication failed to CloudForms."
  echo "$tok"
  exit $err
fi
tok=`echo $tok|python -m json.tool|grep auth_token|cut -f4 -d\"`
#echo "tok is '$tok'"
if [ -z "$tok" ]
then
  echo "ERROR: Authentication failed to CloudForms."
  exit 1
fi

catalogName=`echo $catalogName|sed "s/ /+/g"`
catalogID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs?attributes=name,id&expand=resources&filter%5B%5D=name='$catalogName'" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,\"]//g"`
if [ -z "$catalogID" ]
then
  echo "ERROR: No such catalog $catalogName"
  exit 1
fi
echo "catalogID is $catalogID"

itemName=`echo $itemName|sed "s/ /+/g"`
itemID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_templates?attributes=service_template_catalog_id,id,name&expand=resources&filter%5B%5D=name='$itemName'&filter%5B%5D=service_template_catalog_id='$catalogID'" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,\"]//g"`
if [ -z "$itemID" ]
then
  echo "ERROR: No such catalog item $itemName"
  exit 1
fi
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
  tok=`curl -s $ssl --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth|python -m json.tool|grep auth_token|cut -f4 -d\"`
  while [ $c -le $groupCount -a $t -le $totalRequests ]
  do
    echo "Deploying request $t in group $g"
    out=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X POST $uri/api/service_catalogs/$catalogID/service_templates -d "$PAYLOAD" | python -m json.tool`
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
