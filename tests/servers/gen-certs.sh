#!/usr/bin/env bash
# Makes a test CA and a server certificate for 127.0.0.1 and localhost.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)/certs"
mkdir -p "$dir" && cd "$dir"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=redisrs-test-ca" -keyout ca.key -out ca.crt
openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" -keyout server.key -out server.csr
printf "subjectAltName=DNS:localhost,IP:127.0.0.1
" > san.ext
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 -extfile san.ext -out server.crt
chmod 644 ./*.key
