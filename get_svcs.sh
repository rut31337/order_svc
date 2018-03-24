#!/bin/bash

# CloudForms Get Services - Patrick Rutledge prutledg@redhat.com

# Defaults
uri="https://cf.example.com"

# Dont touch from here on

usage() {
  echo "Error: Usage $0 -c <catalog name> -i <item name> -u <username> -o <outfile> [ -w <uri> -N ]"
}

while getopts Nu:c:i:w:o: FLAG; do
  case $FLAG in
    u) username="$OPTARG";;
    N) insecure=1;;
    c) catalogName="$OPTARG";;
    i) itemName="$OPTARG";;
    w) uri="$OPTARG";;
    o) outfile="$OPTARG";;
    *) usage;exit;;
    esac
done

if [ -z "$catalogName" -o -z "$itemName" -o -z "$outfile" ]
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

if [ "$insecure" == 1 ]
then
  ssl="-k"
else
  ssl=""
fi

tok=`curl -s $ssl --user $username:$password -X GET -H "Accept: application/json" $uri/api/auth|python -m json.tool|grep auth_token|cut -f4 -d\"`

catalogName=`echo $catalogName|sed "s/ /+/g"`
itemName=`echo $itemName|sed "s/ /+/g"`
catalogID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_catalogs?attributes=name,id&expand=resources&filter%5B%5D=name%3D$catalogName" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,]//g"`
echo "catalogID is $catalogID"
itemID=`curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET "$uri/api/service_templates?attributes=service_template_catalog_id,id,name&expand=resources&filter%5B%5D=name=$itemName&filter%5B%5D=service_template_catalog_id%3D$catalogID" | python -m json.tool |grep '"id"' | cut -f2 -d:|sed "s/[ ,]//g"`
echo "itemID is $itemID"

curl -s $ssl -H "X-Auth-Token: $tok" -H "Content-Type: application/json" -X GET $uri/api/services?attributes=name\&expand=resources\&filter%5B%5D=service_template_id%3D$itemID|python -m json.tool|grep '"name"'|grep $username|cut -f2 -d:|sed -e 's/[ |"]//g' > $outfile
