#!/bin/bash

function usage {
cat << EndOfUsage

Usage: ./gratisddns.sh [OPTIONS..]

Required options:

  -u/--user <user>

  -p/--password <ddns password>

  -a/--accountdomain <account domain>

  -d/--dyndomain <domain name to update>

Optional options:
  
  -i/--detectip 
    This tells the script to include our external ip as an explicit url parameter. Using this adds a dependency on
    the 'dig' command from the 'bind-utils' package. You don't seem to need this.

EndOfUsage
}

# Parse command line arguments
while [[ $# > 0 ]]; do
  key="$1"

  case $key in
    -h|--help)
    usage
    exit 0
    ;;
    -u|--user)
    DDNSUSER="$2"
    shift # past argument
    ;;
    -p|--password)
    PASSWORD="$2"
    shift # past argument
    ;;
    -a|--accountdomain)
    ACCOUNT_DOMAIN="$2"
    shift # past argument
    ;;
    -d|--dyndomain)
    DYN_DOMAIN="$2"
    shift # past argument
    ;;
    -i|--detectip)
    DETECT_IP=YES
    shift # past argument
    ;;
    *)
      # unknown option
      echo "Unknown option: $key" >&2
      usage >&2
      exit 1
    ;;
  esac
  shift # past argument or value
done

function validateArg {
  if [ -z "$1" ]; then
    echo "Missing argument: $2" >&2
    usage >&2
    exit 2
  fi
  if [ -n "$2" ]; then
    echo "$2" = "$1"
  fi
}

validateArg "$DDNSUSER" "user"
validateArg "$PASSWORD"
validateArg "$ACCOUNT_DOMAIN" "accountdomain"
validateArg "$DYN_DOMAIN" "dyndomain"


# Done parsing/validating arguments


# If we are supposed to detect ip, do that before we issue the request to gratisdns.dk
if [ -n "$DETECT_IP" ]; then
  # Verify presence of dig command and provide advice if it is missing

  if ! type "dig" &> /dev/null; then
    cat << EndOfError >&2
This scripts requires the command 'dig'. You can probably install it in one of the following ways:

sudo yum install bind-utils
sudo apt-get install bind-utils

EndOfError
    exit 3
  fi

  echo "Resolving external ip address using opendns.."

  externalIp="$(dig +short myip.opendns.com @resolver1.opendns.com)"

  if [ $? -ne 0 ]; then
    echo "External ip detection failed" >&2
    exit 1
  fi

  echo "Got external ip address $externalIp"

  externalIpArg="&i=${externalIp}"
fi

# Done detecting external ip

baseUrl="https://ssl.gratisdns.dk/ddns.phtml"
gratisdnsUrl="${baseUrl}?u=${DDNSUSER}&p=${PASSWORD}&d=${ACCOUNT_DOMAIN}&h=${DYN_DOMAIN}${externalIpArg}"

echo "Initiating request to ${baseUrl}.."

curl "$gratisdnsUrl"

