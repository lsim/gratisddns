#!/bin/bash

scriptDir=$( cd "$(dirname "$0")" ; pwd -P )
scriptPath="${scriptDir}/$(basename "$0")"
crondPath="/etc/cron.d/1gratisddns"

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

  -s/--schedule
    Causes this script to schedule itself for regular runs with the given arguments.

  -c/--cancel
    Causes this script to unschedule itself
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
    -s|--schedule)
    SCHEDULE=YES
    shift # past argument
    ;;
    -c|--cancel)
    echo "Cancelling gratisddns schedule (if there was one)"
    sudo rm "$crondPath"
    exit
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
  if [ -z "$3" ]; then
    echo "$2" = "$1"
  fi
}

validateArg "$DDNSUSER" "user"
validateArg "$PASSWORD" "password" "dontprint"
validateArg "$ACCOUNT_DOMAIN" "accountdomain"
validateArg "$DYN_DOMAIN" "dyndomain"


# Done parsing/validating arguments

if [ -n "$SCHEDULE" ]; then
  echo "Creating schedule to run this script every three hours and log to /tmp/gratisddns.log"
  echo "01 0-23/3 * * * $USER $scriptPath -u $DDNSUSER -p $PASSWORD -a $ACCOUNT_DOMAIN -d $DYN_DOMAIN > /tmp/gratisddns.log 2>&1" | sudo tee "$crondPath" >/dev/null
  exit
fi

if [ -n "$EXPLICIT_IP" ]; then

  externalIpArg="&i=${EXPLICIT_IP}"

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


# Time to submit the request


baseUrl="https://ssl.gratisdns.dk/ddns.phtml"
gratisdnsUrl="${baseUrl}?u=${DDNSUSER}&p=${PASSWORD}&d=${ACCOUNT_DOMAIN}&h=${DYN_DOMAIN}${externalIpArg}"

echo "Initiating request to ${baseUrl}.."

curl -sS "$gratisdnsUrl"

