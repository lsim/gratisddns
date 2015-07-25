#!/bin/bash

# Expects the package bind-utils to be installed (for the command dig)
# Verify presence of dig command and provide advice if it is missing

if ! type "dig" &> /dev/null; then
  cat << EndOfError >&2
This scripts requires the command 'dig', which might be installed in one of the following ways:

sudo yum install bind-utils
sudo apt-get install bind-utils

EndOfError
  exit 3
fi

function usage {
cat << EndOfUsage

Usage: ./gratisddns.sh [REQUIRED OPTIONS..]

Required options:

  -u/--user <user>

  -p/--password <ddns password>

  -a/--accountdomain <account domain>

  -d/--dyndomain <domain name to update>

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
    ;;    --default)
    DEFAULT=YES
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


echo "Resolving external ip address using opendns.."

externalIp="$(dig +short myip.opendns.com @resolver1.opendns.com)"

if [ $? -ne 0 ]; then
  echo "Failed getting external ip" >&2
  exit 1
fi

echo "Got external ip address $externalIp"

gratisdnsUrl="https://ssl.gratisdns.dk/ddns.phtml?u=${DDNSUSER}&p=${PASSWORD}&d=${ACCOUNT_DOMAIN}&h=${DYN_DOMAIN}&i=${externalIp}"

echo "Initiating request to https://ssl.gratisdns.dk/ddns.phtml .."

curl "$gratisdnsUrl"