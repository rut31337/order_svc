#!/bin/bash

# CloudForms Retire Services - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -c <catalog name> -i <item name> -u <username> [ -P <password> -w <uri> -n -N ]"
}

while getopts Nnu:P:c:i:w: FLAG; do
  case $FLAG in
    n) noni=1;;
    N) insecure=1;;
    u) username="$OPTARG";;
    P) password="$OPTARG";;
    c) catalogName="$OPTARG";;
    i) itemName="$OPTARG";;
    w) uri="$OPTARG";;
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

tok=`curl -s $ssl --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth|python -m json.tool|grep auth_token|cut -f4 -d\"`

if [ -z "$tok" ]
then
  echo "ERROR: Authentication failed to CloudForms."
  exit 1
fi

catalogName=`echo $catalogName|sed "s/ /+/g"`
catalogID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs?attributes=name,id&expand=resources&filter%5B%5D=name='$catalogName'" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,\"]//g"`
if [ -z "$catalogID" ]
then
  echo "ERROR: Invalid Catalog $catalogName"
  exit 1
fi
echo "catalogID is $catalogID"


itemName=`echo $itemName|sed "s/ /+/g"`
itemID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_templates?attributes=service_template_catalog_id,id,name&expand=resources&filter%5B%5D=name='$itemName'&filter%5B%5D=service_template_catalog_id='$catalogID'" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,\"]//g"`
if [ -z "$itemID" ]
then
  echo "ERROR: Invalid Catalog item $itemName"
  exit 1
fi
echo "itemID is $itemID"

svcs=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/services?attributes=href&expand=resources&filter%5B%5D=service_template_id='$itemID'" | python -m json.tool |grep '"href"'|grep "services/"|cut -f2- -d:|sed -e "s/[ ,\"]//g"`

if [ "$noni" != 1 ]
then
  echo -n "Are you sure you wish to retire/delete ALL services deployed from this catalog item? (y/N): ";read yn
  if [ "$yn" != "y" ]
  then
    echo "Exiting."
    exit
  fi
fi

PAYLOAD="{ \"action\": \"retire\" }"

echo -n "Retiring Services"
for svc in $svcs
do
  output=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X POST $svc -d "$PAYLOAD"`
  echo -n "."
  sleep 1
done
echo
