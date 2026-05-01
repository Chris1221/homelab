
# Install acme.sh if not already installed
if ! command -v acme.sh &> /dev/null
then
    echo "acme.sh not found, installing..."
    curl https://get.acme.sh | sh
    source ~/.bashrc

    acme.sh --register-account -m $USER_EMAIL
fi

# Load environment variables from .env file
# which include the CF_Token variable from 
# Cloudflare needed for DNS validation.
#
# This token is scoped to Edit DNS
set +a; source .env; set -a

# Issue a wildcard certificate for the domain and
# copy it to the traefik certs directory.
CERTS_DIR="./certs/"
$HOME/.acme.sh/acme.sh --issue --dns dns_cf -d "*.${DOMAIN}" -d "${DOMAIN}" --log --debug
cp ~/.acme.sh/\*.${DOMAIN}_ecc/* $CERTS_DIR/

echo "Certificate issued and copied to $CERTS_DIR, they are valid for 90 days."