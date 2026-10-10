#!/usr/bin/env bash
set -Eeuo pipefail

# WhatsApp Official Proxy installer
# Supported: Ubuntu/Debian with systemd
# Default public endpoint: TCP 443

readonly CONTAINER_NAME="whatsapp-proxy"
readonly IMAGE="facebook/whatsapp_proxy:latest"
readonly DATA_DIR="/opt/whatsapp-proxy"
readonly INSTALL_PIN="027005"

log() { printf '\n[%s] %s\n' "INFO" "$*"; }
fail() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

check_pin() {
  local entered_pin
  for attempt in 1 2 3; do
    read -r -s -p "Masukkan PIN instalasi: " entered_pin
    printf '\n'
    if [[ "${entered_pin}" == "${INSTALL_PIN}" ]]; then
      return 0
    fi
    printf 'PIN salah. Percobaan %s/3.\n' "${attempt}" >&2
  done
  fail "Terlalu banyak percobaan PIN yang salah."
}

check_pin

[[ "${EUID}" -eq 0 ]] || fail "Jalankan sebagai root: sudo bash $0"
command -v systemctl >/dev/null 2>&1 || fail "OS ini tidak menggunakan systemd. Gunakan Ubuntu/Debian dengan systemd."

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
else
  fail "Tidak dapat mendeteksi sistem operasi."
fi
case "${ID:-}" in
  ubuntu|debian) ;;
  *) fail "OS tidak didukung: ${ID:-unknown}. Gunakan Ubuntu atau Debian." ;;
esac

export DEBIAN_FRONTEND=noninteractive

# Some VPS images contain an expired or blocked Caddy Cloudsmith source.
# It is unrelated to this installer and can make apt-get update abort.
while IFS= read -r -d '' source_file; do
  backup_file="${source_file}.disabled-by-whatsapp-proxy-installer"
  if [[ ! -e "${backup_file}" ]]; then
    mv "${source_file}" "${backup_file}"
    log "Menonaktifkan sumber APT Caddy bermasalah: ${source_file}"
  fi
done < <(grep -RIlZ --include='*.list' --include='*.sources' 'dl\.cloudsmith\.io/public/caddy' /etc/apt/sources.list.d 2>/dev/null || true)

apt-get update
apt-get install -y ca-certificates curl ufw

if ! command -v docker >/dev/null 2>&1; then
  log "Menginstal Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/${ID}/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  printf 'Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
    "${ID}" "${VERSION_CODENAME}" "$(dpkg --print-architecture)" \
    >/etc/apt/sources.list.d/docker.sources
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable --now docker
mkdir -p "${DATA_DIR}"

PUBLIC_IP="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"
[[ -n "${PUBLIC_IP}" ]] || PUBLIC_IP="$(hostname -I | awk '{print $1}')"

printf '\nKonfigurasi opsional\n'
printf '%s\n' "- Jika memakai domain/subdomain, masukkan sekarang agar sertifikat internal memuat nama tersebut."
printf '%s\n' "- Tekan Enter untuk menggunakan IP publik: ${PUBLIC_IP}"
read -r -p "Domain/subdomain (opsional): " SSL_DNS

if [[ -n "${SSL_DNS}" ]]; then
  [[ "${SSL_DNS}" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Format domain tidak valid."
  SSL_ARGS=(--env "SSL_DNS=${SSL_DNS}" --env "SSL_IP=${PUBLIC_IP}")
else
  SSL_ARGS=(--env "SSL_IP=${PUBLIC_IP}")
fi

log "Mengambil image resmi ${IMAGE}..."
if ! timeout 300 docker pull "${IMAGE}"; then
  printf '\n[ERROR] Docker Registry tidak merespons atau image gagal diunduh setelah 5 menit.\n' >&2
  printf '%s\n' "Periksa koneksi dengan: curl -4I --max-time 15 https://registry-1.docker.io/v2/" >&2
  printf '%s\n' "Periksa daemon dengan: systemctl status docker --no-pager" >&2
  printf '%s\n' "Log daemon: journalctl -u docker -n 80 --no-pager" >&2
  exit 1
fi

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
log "Menjalankan proxy pada TCP port 443..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --publish 443:443/tcp \
  "${SSL_ARGS[@]}" \
  "${IMAGE}"

# Keep the host firewall focused on the requested public endpoint.
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow 443/tcp comment 'WhatsApp Proxy' >/dev/null
ufw --force enable >/dev/null

sleep 3
if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  docker logs "${CONTAINER_NAME}" || true
  fail "Container tidak berhasil berjalan."
fi

cat >"${DATA_DIR}/README.txt" <<EOF
WhatsApp Proxy container: ${CONTAINER_NAME}
Public endpoint: ${PUBLIC_IP}:443
Container image: ${IMAGE}

Commands:
  docker ps --filter name=${CONTAINER_NAME}
  docker logs -f ${CONTAINER_NAME}
  docker restart ${CONTAINER_NAME}
  docker rm -f ${CONTAINER_NAME}
EOF

log "Instalasi selesai."
printf '%s\n' "Endpoint proxy: ${PUBLIC_IP}:443"
printf '%s\n' "Cek status: docker ps --filter name=${CONTAINER_NAME}"
printf '%s\n' "Log: docker logs -f ${CONTAINER_NAME}"
printf '%s\n' "Catatan: port 443 dipakai sesuai permintaan. Dukungan media yang lebih lengkap dapat memerlukan port 587."
