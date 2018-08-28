#!/bin/bash

# CloudForms Get Services - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -u <username> -c <catalogName> [ -P <password> -w <uri> -N ]"
}

while getopts Nu:c:w:P: FLAG; do
  case $FLAG in
    u) username="$OPTARG";;
    c) catalogName="$OPTARG";;
    P) password="$OPTARG";;
    N) insecure=1;;
    w) uri="$OPTARG";;
    *) usage;exit;;
    esac
done

if [ -z "$catalogName" ]
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

catalogName=`echo $catalogName|sed "s/ /+/g"`
catalogID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs?attributes=name,id&expand=resources&filter%5B%5D=name='$catalogName'" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,\"]//g"`
stIDs=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/services?attributes=service_template_id&expand=resources" | python -m json.tool | grep '"service_template_id"'|cut -f2 -d:|sed -e "s/[ \"]//g"`

for sti in $stIDs
do
  curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs/$catalogID/service_templates/$sti?attributes=name" | python -m json.tool | grep '"name"'|cut -f2 -d:|sed -e "s/[ \"]//g"
done

