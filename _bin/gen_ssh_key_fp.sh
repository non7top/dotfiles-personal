openssl pkcs8 -in "$1" -inform PEM -outform DER -topk8 -nocrypt | openssl sha1 -c
