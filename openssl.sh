#! /bin/bash

# Exit script if any command returns non-zero status
set -e

# Define some colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Set default values
DOMAIN="$(hostname)"
DIRECTORY="."

# Check flags
while getopts ':d:p:' opt; do
    case "${opt}" in
        d ) DOMAIN=$OPTARG ;;
        p ) DIRECTORY=$OPTARG ;;
        \? ) echo -e "${RED}Invalid option: $OPTARG${NC}" 1>&2
             exit 1 ;;
        : ) echo -e "${RED}Invalid option: $OPTARG requires an argument${NC}" 1>&2
            exit 1 ;;
    esac
done

# Set directories
CERT_DIRECTORY="${DIRECTORY}/${DOMAIN}"
CA_DIRECTORY="${DIRECTORY}/CA"

generate_root_ca() {
    echo -e "${GREEN}Generating rootCA certificate and key in ${CA_DIRECTORY}${NC}"

    if [ ! -f "${CA_DIRECTORY}/rootCA.crt" ] || [ ! -f "${CA_DIRECTORY}/rootCA.key" ] ; then
        echo "Generating root CA..."
        openssl req -x509 \
                        -sha256 -days 356 \
                        -nodes \
                        -newkey rsa:2048 \
                        -subj "/CN=${DOMAIN}/C=DE/L=Saxony" \
                        -keyout "${CA_DIRECTORY}/rootCA.key" \
                        -out "${CA_DIRECTORY}/rootCA.crt"
    else echo "Root certificate already exists."
    fi

}

generate_private_key() {
    echo -e "${GREEN}Generating private key...${NC}"
    openssl genrsa -out "${CERT_DIRECTORY}/privkey.pem" 2048
    echo "Private key generated: ${CERT_DIRECTORY}/privkey.pem"
}

generate_csr() {
    echo -e "${GREEN}Generating CSR...${NC}"
    echo "Creating CSR configuration: ${CERT_DIRECTORY}/csr.conf"
    cat > "${CERT_DIRECTORY}/csr.conf" <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = DE
ST = Saxony
L = Dresden
O = Systema GmbH
OU = Systema GmbH
CN = ${DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
DNS.2 = www.${DOMAIN}
IP.1 = 192.168.1.5
IP.2 = 192.168.1.6

EOF

    echo "Creating CSR: ${CERT_DIRECTORY}/csr.pem"
    openssl req -new -key "${CERT_DIRECTORY}/privkey.pem" \
        -out "${CERT_DIRECTORY}/csr.pem" \
        -config "${CERT_DIRECTORY}/csr.conf"
}

create_cert() {
    echo -e "${GREEN}Creating certificate...${NC}"
    echo "Creating config file for certificate: ${CERT_DIRECTORY}/cert.conf"
    cat > "${CERT_DIRECTORY}/cert.conf" <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}

EOF

    echo "Creating certificate: ${CERT_DIRECTORY}/cert.pem"
    openssl x509 -req \
        -in "${CERT_DIRECTORY}/csr.pem" \
        -CA "${CA_DIRECTORY}/rootCA.crt" -CAkey "${CA_DIRECTORY}/rootCA.key" \
        -CAcreateserial -out "${CERT_DIRECTORY}/cert.pem" \
        -days 365 \
        -sha256 -extfile "${CERT_DIRECTORY}/cert.conf"

    echo -e "Creating fullchain: ${CERT_DIRECTORY}/fullchain.pem"
    cat "${CERT_DIRECTORY}/cert.pem" "${CA_DIRECTORY}/rootCA.crt" >> "${CERT_DIRECTORY}/fullchain.pem"
}

verify_chain() {
    echo -e "${GREEN}Verifying certificate chain...${NC}"
    openssl verify -show_chain -CAfile "${CERT_DIRECTORY}/fullchain.pem" "${CERT_DIRECTORY}/cert.pem"
}

echo -e "${GREEN}Generating certificates for domain: ${DOMAIN} in ${DIRECTORY}${NC}"

echo "Creating directory for CA ${CA_DIRECTORY} and certs ${CERT_DIRECTORY}"
mkdir -p "${CA_DIRECTORY}"
mkdir -p "${CERT_DIRECTORY}"
echo ""

generate_root_ca
echo ""

generate_private_key
echo ""

generate_csr
echo ""

create_cert
echo ""

verify_chain
