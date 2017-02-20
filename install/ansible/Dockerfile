FROM alpine:3.5
MAINTAINER contiv

RUN DEV_PACKAGES="python-dev py-pip gcc musl-dev openssl-dev libffi-dev" \
 && apk add --no-cache python openssl libffi $DEV_PACKAGES \
 && pip install --upgrade pip \
 && pip install ansible==2.2.1.0 \
 && apk del $DEV_PACKAGES
