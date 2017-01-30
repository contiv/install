#!/bin/bash

set -euo pipefail

PREFIX="./local_certs"
KEY_PATH="$PREFIX/local.key"
CERT_PATH="$PREFIX/cert.pem"

# if both files exist, just exit
if [[ -f $KEY_PATH && -f $CERT_PATH ]]; then
    exit 0
fi

rm -f $KEY_PATH
rm -f $CERT_PATH

openssl genrsa -out $KEY_PATH 2048 >/dev/null 2>&1
openssl req -new -x509 -sha256 -days 3650 \
	-key $KEY_PATH \
	-out $CERT_PATH \
	-subj "/C=US/ST=CA/L=San Jose/O=CPSG/OU=IT Department/CN=auth-local.cisco.com"

echo "Created $KEY_PATH and $CERT_PATH"
