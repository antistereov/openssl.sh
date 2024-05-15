# openssl.sh

This script generates self-signed certificates for a given domain into a given direcory.
It is based on the following tutorial: [How to Create Self-Signed Certificates using OpenSSL](https://devopscube.com/create-self-signed-certificates-openssl/)

## Usage

```shell
./openssl.sh -d <domain-name> -p <directory>
```

This will create a certificate authority (CA) in `<directory>/CA`, a certificate signing request CSR and the following certificates and keys into `<directory>/<domain-name>`:

* `privkey.pem`: the private key
* `cert.pem`: the intermediate certificate
* `fullchain.pem`: the full chain
