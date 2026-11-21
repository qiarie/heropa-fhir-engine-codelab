#!/usr/bin/env bash
#
# lab-init.sh starts the codelab lab on this VM and prints where to open it.
# A learner runs it once after the lab launches. Running it again is safe and
# prints the same addresses and password.
#
#   ./lab-init.sh            start the lab
#   ./lab-init.sh --reset    throw away the learner's code and the FHIR server data and start from
#                            the starter
#   ./lab-init.sh --clean    stop everything and remove .env, the password and
#                            the certificate, ready for saving as a template
#
# It does five things.
#
#   1. Works out the lab address. It reads the VM's public IP from the AWS
#      instance metadata service and uses https://<a-b-c-d>.sslip.io, a name
#      that sslip.io's public DNS answers with that IP.
#   2. Creates .env with that address and a password for the editor.
#   3. Gets a Let's Encrypt certificate for that name through the certbot
#      image, for nginx to serve on 443.
#   4. Starts the workspace, the FHIR server and nginx with docker compose.
#   5. Waits for the editor and the FHIR server to answer.
#
# Settings come from the environment, then .env, then .env.example.
#
#   PUBLIC_IP      skips the metadata lookup, for testing off Heropa
#   LAB_HOST       skips the sslip.io name as well, for example localhost
#   LAB_CERT       letsencrypt, self-signed or none. none serves plain HTTP
#                  and is only allowed with LAB_HOST=localhost, where the
#                  browser needs no certificate to treat the page as secure.
#   CERTBOT_EMAIL  Let's Encrypt account address, optional
#   LAB_HTTP_PORT and LAB_HTTPS_PORT, the ports nginx publishes
#
# For a Let's Encrypt certificate the Heropa VM needs a permanent public IP
# and inbound TCP 80 and 443 from 0.0.0.0/0. Let's Encrypt checks over port 80
# from addresses it does not publish, so that rule cannot be narrowed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
EXAMPLE_FILE="$SCRIPT_DIR/.env.example"
CERTBOT_IMAGE="certbot/certbot:v3.0.1"
CERT_DIR="$SCRIPT_DIR/certs"
# Kept apart from CERT_DIR so --clean leaves the Let's Encrypt account and
# certificate alone. Let's Encrypt issues the same name only five times a
# week, so a test cycle of clean and init must not ask for a new one each time.
LE_DIR="$SCRIPT_DIR/letsencrypt"

info()  { printf '\033[0;32m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*" >&2; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

compose() { docker compose --project-directory "$SCRIPT_DIR" "$@"; }

# --- arguments --------------------------------------------------------------

RESET=0
CLEAN=0
for arg in "$@"; do
    case "$arg" in
        --reset) RESET=1 ;;
        --clean) CLEAN=1 ;;
        *)       error "Unknown option $arg. Use --reset, --clean or nothing." ;;
    esac
done

# --- .env helpers -----------------------------------------------------------

# Prints the value of KEY in .env, or in the file given as the second
# argument, without surrounding quotes.
env_get() {
    local file="${2:-$ENV_FILE}"
    [[ -f "$file" ]] || return 0
    sed -n "s/^$1=//p" "$file" | tail -n 1 | sed -e 's/^"//' -e 's/"$//'
}

# Reads KEY from the environment, then .env, then .env.example.
setting() {
    local value="${!1:-}"
    [[ -n "$value" ]] || value="$(env_get "$1")"
    [[ -n "$value" ]] || value="$(env_get "$1" "$EXAMPLE_FILE")"
    printf '%s' "$value"
}

# Sets KEY to VALUE in .env, replacing an existing line or appending one.
env_set() {
    local tmp
    [[ "$2" != *[\"\$\`\\]* ]] || error "Refusing to write $1 with a quote, dollar, backtick or backslash in it."
    tmp="$(mktemp "${TMPDIR:-/tmp}/engine-lab-env.XXXXXX")"
    KEY="$1" VALUE="$2" awk '
        BEGIN { key = ENVIRON["KEY"]; line = key "=\"" ENVIRON["VALUE"] "\"" }
        index($0, key "=") == 1 { if (!done) print line; done = 1; next }
        { print }
        END { if (!done) print line }
    ' "$ENV_FILE" > "$tmp"
    cat "$tmp" > "$ENV_FILE"
    rm -f "$tmp"
}

# --- 1. preflight -----------------------------------------------------------

command -v docker  >/dev/null 2>&1 || error "docker is not installed. Run provision-heropa.sh first."
command -v curl    >/dev/null 2>&1 || error "curl is not installed."
command -v openssl >/dev/null 2>&1 || error "openssl is not installed. Run sudo apt-get install -y openssl"
docker info >/dev/null 2>&1 \
    || error "Cannot talk to Docker. Log out and back in, or run newgrp docker, then retry."

if (( CLEAN )); then
    info "Stopping the lab, the FHIR server and removing the learner volume"
    # compose needs these two to read the file at all. Their values do not
    # matter for a shutdown.
    IDE_PASSWORD=x LAB_URL=x compose down --volumes --remove-orphans
    rm -rf "$ENV_FILE" "$CERT_DIR"
    info "Removed .env and the certificate. The images and $LE_DIR are kept."
    exit 0
fi

if [[ ! -f "$ENV_FILE" ]]; then
    info "No .env found, so creating it from .env.example"
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

# --- 2. lab address ---------------------------------------------------------

# IMDSv2 first, which needs a session token, then IMDSv1 for older instances.
lookup_public_ip() {
    local base="http://169.254.169.254/latest" token
    token="$(curl -fsS -m 3 -X PUT "$base/api/token" \
        -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null || true)"
    if [[ -n "$token" ]]; then
        curl -fsS -m 3 -H "X-aws-ec2-metadata-token: $token" \
            "$base/meta-data/public-ipv4" 2>/dev/null && return 0
    fi
    curl -fsS -m 3 "$base/meta-data/public-ipv4" 2>/dev/null
}

LAB_HOST="${LAB_HOST:-}"
if [[ -z "$LAB_HOST" ]]; then
    PUBLIC_IP="${PUBLIC_IP:-$(lookup_public_ip || true)}"
    [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || error "Could not read a public IPv4 address. Give the VM a permanent public IP in Heropa, or set PUBLIC_IP."
    info "Public IP is $PUBLIC_IP"
    LAB_HOST="${PUBLIC_IP//./-}.sslip.io"
fi

HTTP_PORT="$(setting LAB_HTTP_PORT)";   HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="$(setting LAB_HTTPS_PORT)"; HTTPS_PORT="${HTTPS_PORT:-443}"
LAB_CERT="$(setting LAB_CERT)"
LAB_CERT="${LAB_CERT:-letsencrypt}"
[[ "$LAB_CERT" == letsencrypt || "$LAB_CERT" == self-signed || "$LAB_CERT" == none ]] \
    || error "LAB_CERT must be letsencrypt, self-signed or none, not $LAB_CERT"

if [[ "$LAB_CERT" == none ]]; then
    # The editor's web views need a secure page. Without a certificate only
    # localhost counts as one.
    [[ "$LAB_HOST" == localhost || "$LAB_HOST" == 127.0.0.1 ]] \
        || error "LAB_CERT=none only works with LAB_HOST=localhost."
    LAB_URL="http://$LAB_HOST"
    [[ "$HTTP_PORT" == 80 ]] || LAB_URL="$LAB_URL:$HTTP_PORT"
    LAB_PORT="$HTTP_PORT"
    NGINX_CONF="lab-http"
else
    LAB_URL="https://$LAB_HOST"
    [[ "$HTTPS_PORT" == 443 ]] || LAB_URL="$LAB_URL:$HTTPS_PORT"
    LAB_PORT="$HTTPS_PORT"
    NGINX_CONF="lab-https"
fi
CERTBOT_EMAIL="$(setting CERTBOT_EMAIL)"

if [[ "$LAB_CERT" == none ]]; then
    info "The lab will answer at $LAB_URL over plain HTTP, for a local test"
else
    info "The lab will answer at $LAB_URL with a $LAB_CERT certificate"
fi

# --- 3. .env ----------------------------------------------------------------

# The password is made once and kept, so a second run prints the same one.
IDE_PASSWORD="$(env_get IDE_PASSWORD)"
if [[ -z "$IDE_PASSWORD" ]]; then
    IDE_PASSWORD="$(openssl rand -hex 6)"
    info "Created a password for the editor"
fi

env_set LAB_URL        "$LAB_URL"
env_set IDE_PASSWORD   "$IDE_PASSWORD"
env_set LAB_CERT       "$LAB_CERT"
env_set LAB_NGINX_CONF "$NGINX_CONF"
# Tells the FHIR server which scheme to write into the links it returns.
if [[ "$LAB_CERT" == none ]]; then env_set LAB_FHIR_HTTPS "false"; else env_set LAB_FHIR_HTTPS "true"; fi
env_set LAB_HTTP_PORT  "$HTTP_PORT"
env_set LAB_HTTPS_PORT "$HTTPS_PORT"

# --- 4. certificate ---------------------------------------------------------

mkdir -p "$CERT_DIR"

# True when lab.crt names LAB_HOST and stays valid for at least DAYS more.
cert_fits() {
    local days="$1"
    openssl x509 -in "$CERT_DIR/lab.crt" -noout -checkhost "$LAB_HOST" 2>/dev/null | grep -q 'does match' \
        && openssl x509 -in "$CERT_DIR/lab.crt" -noout -checkend $(( days * 86400 )) >/dev/null 2>&1 \
        && [[ -s "$CERT_DIR/lab.key" ]]
}

# True when lab.crt signed itself, which is how a leftover test certificate
# is told apart from a Let's Encrypt one.
cert_self_signed() {
    [[ "$(openssl x509 -in "$CERT_DIR/lab.crt" -noout -subject 2>/dev/null | sed 's/^subject=//')" \
        == "$(openssl x509 -in "$CERT_DIR/lab.crt" -noout -issuer 2>/dev/null | sed 's/^issuer=//')" ]]
}

if [[ "$LAB_CERT" == letsencrypt ]]; then
    if cert_fits 30 && ! cert_self_signed; then
        info "The Let's Encrypt certificate for $LAB_HOST is already in place"
    else
        info "Requesting a Let's Encrypt certificate for $LAB_HOST"
        email_args=(--register-unsafely-without-email)
        [[ -n "$CERTBOT_EMAIL" ]] && email_args=(--email "$CERTBOT_EMAIL")

        # certbot answers the check on port 80 itself, so nginx gives the port
        # up for the minute this takes. It starts again below.
        docker stop engine-nginx >/dev/null 2>&1 || true
        mkdir -p "$LE_DIR"
        docker run --rm -p "$HTTP_PORT:80" -v "$LE_DIR:/etc/letsencrypt" "$CERTBOT_IMAGE" \
            certonly --standalone --non-interactive --agree-tos --keep-until-expiring \
            "${email_args[@]}" --cert-name "$LAB_HOST" -d "$LAB_HOST" \
            || error "certbot failed. Check that the Heropa network rules allow inbound TCP 80 from 0.0.0.0/0 and that $LAB_HOST resolves to this VM's public IP."

        # certbot writes as root and keeps symlinks under live/. Copy plain
        # files that nginx can read and this user can replace later.
        docker run --rm -v "$LE_DIR:/etc/letsencrypt" -v "$CERT_DIR:/out" \
            --entrypoint sh "$CERTBOT_IMAGE" -c '
                cp -L "/etc/letsencrypt/live/$1/fullchain.pem" /out/lab.crt &&
                cp -L "/etc/letsencrypt/live/$1/privkey.pem" /out/lab.key &&
                chown "$2" /out/lab.crt /out/lab.key &&
                chmod 644 /out/lab.crt /out/lab.key' sh "$LAB_HOST" "$(id -u):$(id -g)" \
            || error "Could not copy the certificate out of $LE_DIR."
    fi
elif [[ "$LAB_CERT" == self-signed ]] && ! cert_fits 1; then
    info "Making a self-signed certificate for $LAB_HOST"
    rm -f "$CERT_DIR/lab.crt" "$CERT_DIR/lab.key"
    openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
        -subj "/CN=$LAB_HOST" -addext "subjectAltName=DNS:$LAB_HOST" \
        -keyout "$CERT_DIR/lab.key" -out "$CERT_DIR/lab.crt" 2>/dev/null
    chmod 644 "$CERT_DIR/lab.key"   # read by nginx inside its container
fi

# --- 5. start ---------------------------------------------------------------

if (( RESET )); then
    warn "Throwing away the learner's code and starting again from the starter"
    compose down --volumes --remove-orphans
fi

docker image inspect engine-codelab-workspace:local >/dev/null 2>&1 \
    || warn "The workspace image is not built yet. Building it now takes several minutes."

info "Starting the lab"
compose up -d --remove-orphans
# nginx reads the certificate and LAB_URL only when it starts.
compose restart nginx >/dev/null

# The check goes to nginx on this VM, with the lab name pinned to loopback, so
# it works whether or not the VM can reach its own public address.
info "Waiting for the editor to answer"
ready=0
for _ in $(seq 1 60); do
    if curl -fks -m 5 -o /dev/null --resolve "$LAB_HOST:$LAB_PORT:127.0.0.1" "$LAB_URL/ide/healthz"; then
        ready=1
        break
    fi
    sleep 2
done
(( ready )) || warn "The editor did not answer yet. Check with docker compose logs workspace"

# The FHIR server takes a minute or two to start. The seed container loads the
# test patients as soon as it is up, so the wait is for the first of them.
info "Waiting for the FHIR server and its test patients. This can take two minutes."
fhir_ready=0
for _ in $(seq 1 90); do
    if curl -fks -m 5 -o /dev/null --resolve "$LAB_HOST:$LAB_PORT:127.0.0.1" "$LAB_URL/fhir/Patient/codelab-aaron-brekke"; then
        fhir_ready=1
        break
    fi
    sleep 2
done
(( fhir_ready )) || warn "The FHIR server did not answer yet. Check with docker compose logs hapi seed"

cat <<EOF

The lab is ready. Open these in the browser on your own computer.

  Editor            $LAB_URL/ide/
  Editor password   $IDE_PASSWORD
  App               $LAB_URL/preview/
  FHIR server       $LAB_URL/fhir/Patient

The Open app button at the bottom of the Editor also opens the App.
EOF

if [[ "$LAB_CERT" == self-signed ]]; then
    warn "With a self-signed certificate the guide pane and other web views in the editor fail to load, because browsers refuse them on an untrusted certificate. For a local test use LAB_CERT=none."
fi
