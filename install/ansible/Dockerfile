FROM alpine:3.5
MAINTAINER contiv

RUN apk add --no-cache python-dev py-pip gcc musl-dev openssl-dev libffi-dev && \
    pip install --upgrade pip && pip install ansible==2.2.0.0
