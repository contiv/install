FROM alpine:3.6

RUN DEV_PACKAGES="python-dev gcc musl-dev openssl-dev libffi-dev" \
 && apk add --no-cache python openssl libffi nmap-ncat py-pip $DEV_PACKAGES \
 && pip install --upgrade pip \
 && pip install ansible==2.3.1.0 \
 && apk del $DEV_PACKAGES
