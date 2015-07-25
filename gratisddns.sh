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
  
  -t/--detectip 
    This tells the script to include our external ip as a url parameter. Using this adds a dependency on
    the 'dig' command from the 'bind-utils' package. You dont seem to need this.

  -i/--ip <ip address>
    This tells the script to submit the given ip address as a url parameter. This overrules the -t/--detectip
    argument
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
    -t|--detectip)
    DETECT_IP=YES
    shift # past argument
    ;;
    -i|--ip)
    EXPLICIT_IP="$2"
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



if [ -n "$EXPLICIT_IP" ]; then

  externalIpArg="&i=${EXPLICIT_IP}"

# If we are supposed to detect ip, do that before we issue the request to gratisdns.dk
elif [ -n "$DETECT_IP" ]; then
  # Verify presence of dig command and provide advice if it is missing

  if ! type "dig" &> /dev/null; then
    cat << EndOfError >&2
This script requires the command 'dig' when invoked with -t/--detectip. You can probably install it in 
one of the following ways:

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

