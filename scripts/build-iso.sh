#!/bin/bash
# ---------------------------------------------------------------------------
# build-iso.sh - Baut die bootfaehige ISO von Sina Server
#
# Voraussetzungen: Linux (Debian/Ubuntu), root-Rechte, live-build 1:20230502,
# debootstrap, xorriso, squashfs-tools (siehe docs/BUILD.md).
#
# Ergebnis:
#   dist/Sina-Server-<version>-amd64.iso
#   dist/Sina-Server-<version>-amd64.iso.sha256
# ---------------------------------------------------------------------------
set -Eeuo pipefail

PROGRAM=${0##*/}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)

VERSION=$(tr -d ' \t\r\n' <"${PROJECT_DIR}/VERSION")
EDITION=${SINA_EDITION:-Standard Edition}
ARCH=${SINA_ARCH:-amd64}
DISTRO=${SINA_BASE_DISTRO:-noble}
LB_DIR="${PROJECT_DIR}/iso"
DIST_DIR="${PROJECT_DIR}/dist"
ISO_NAME="Sina-Server-${VERSION}-amd64.iso"
LOG_FILE=${SINA_BUILD_LOG:-${PROJECT_DIR}/build.log}

VERIFY=1

log() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mWARNUNG:\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[31mFEHLER:\033[0m %s\n' "$*" >&2
	printf 'Build-Protokoll: %s\n' "${LOG_FILE}" >&2
	exit 1
}

usage() {
	cat <<EOF
Aufruf: sudo ${PROGRAM} [--no-verify]

  --no-verify   ISO nach dem Build nicht pruefen und keine Pruefsumme erzeugen
  -h, --help    Diese Hilfe

Umgebungsvariablen:
  SINA_BASE_DISTRO   Ubuntu-Basis (Standard: noble)
  SINA_ARCH          Architektur (Standard: amd64)
  SINA_EDITION       Edition (Standard: Standard Edition)
  SINA_BUILD_LOG     Pfad des Build-Protokolls
  SOURCE_DATE_EPOCH  Zeitstempel fuer reproduzierbare Builds
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--no-verify) VERIFY=0 ;;
		-h|--help) usage; exit 0 ;;
		*) usage >&2; die "Unbekannte Option: $1" ;;
	esac
	shift
done

# ---------------------------------------------------------------------------
# Voraussetzungen
# ---------------------------------------------------------------------------
[ "$(uname -s)" = "Linux" ] || die "Der Build laeuft nur unter Linux (GitHub Actions oder WSL)."

if [ "$(id -u)" -ne 0 ]; then
	die "Der Build benoetigt root-Rechte: sudo ${PROGRAM} $*"
fi

# live-build weigert sich, in Verzeichnissen mit Leerzeichen zu bauen.
case "${PROJECT_DIR}" in
	*" "*) die "Der Projektpfad enthaelt Leerzeichen: '${PROJECT_DIR}'. Bitte in ein Verzeichnis ohne Leerzeichen klonen." ;;
esac

missing=()
for tool in lb debootstrap xorriso mksquashfs; do
	command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
done
if [ "${#missing[@]}" -gt 0 ]; then
	die "Fehlende Werkzeuge: ${missing[*]}. Installation siehe docs/BUILD.md."
fi

# CRLF-Zeilenenden wuerden Shebangs und Hooks unbrauchbar machen.
if grep -lU $'\r' "${PROJECT_DIR}"/scripts/*.sh "${LB_DIR}/auto/config" \
	"${LB_DIR}"/config/hooks/live/* \
	"${LB_DIR}"/config/includes.chroot/usr/local/bin/* \
	"${LB_DIR}"/config/includes.chroot/usr/local/sbin/* >/dev/null 2>&1; then
	die "Skripte enthalten CRLF-Zeilenenden. Bitte 'dos2unix' bzw. .gitattributes (eol=lf) verwenden."
fi

mkdir -p "${DIST_DIR}"

# ---------------------------------------------------------------------------
# Protokoll (Build-Logs bleiben bei Fehlschlag erhalten)
# ---------------------------------------------------------------------------
exec > >(tee -a "${LOG_FILE}") 2>&1
log "Sina Server ${VERSION} (${EDITION}) - Build gestartet: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "Projekt:          ${PROJECT_DIR}"
log "Basis:            Ubuntu ${DISTRO} (${ARCH})"
log "live-build:       $(lb --version 2>/dev/null || echo unbekannt)"
log "Protokoll:        ${LOG_FILE}"

# ---------------------------------------------------------------------------
# Reproduzierbare Zeitstempel
# ---------------------------------------------------------------------------
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
	if SOURCE_DATE_EPOCH=$(cd "${PROJECT_DIR}" && git log -1 --format=%ct 2>/dev/null); then
		[ -n "${SOURCE_DATE_EPOCH}" ] || SOURCE_DATE_EPOCH=$(date -u +%s)
	else
		SOURCE_DATE_EPOCH=$(date -u +%s)
	fi
fi
export SOURCE_DATE_EPOCH

BUILD_ID=${SINA_BUILD_ID:-$(cd "${PROJECT_DIR}" && git rev-parse --short HEAD 2>/dev/null || echo "lokaler-build")}
BUILD_DATE=$(date -u -d "@${SOURCE_DATE_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ')
BUILD_SOURCE=${SINA_BUILD_SOURCE:-"Lokaler Build $(date -u '+%Y-%m-%d')"}

export SINA_EDITION="${EDITION}"
export SINA_ARCH="${ARCH}"
export SINA_BASE_DISTRO="${DISTRO}"

log "Build-ID:         ${BUILD_ID}"
log "Build-Datum:      ${BUILD_DATE}"
log "SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH}"

# ---------------------------------------------------------------------------
# Image-Metadaten und Dokumentation in das Live-Dateisystem uebernehmen
# ---------------------------------------------------------------------------
log "Release-Datei /etc/sina/release erzeugen"
cat >"${LB_DIR}/config/includes.chroot/etc/sina/release" <<EOF
# Erzeugt von scripts/build-iso.sh - nicht manuell bearbeiten.
PRODUCT=Sina Server
VERSION=${VERSION}
EDITION=${EDITION}
CODENAME=standard
BASE_DISTRIBUTION=Sina Server ${VERSION} (Standard Edition)
BASE_CODENAME=${DISTRO}
BASE_ARCH=${ARCH}
BUILD_ID=${BUILD_ID}
BUILD_DATE=${BUILD_DATE}
BUILD_SOURCE=${BUILD_SOURCE}
EOF

DOC_TARGET="${LB_DIR}/config/includes.chroot/usr/share/doc/sina-server"
rm -rf "${DOC_TARGET}"
install -d -m 0755 "${DOC_TARGET}"
if [ -d "${PROJECT_DIR}/docs" ]; then
	cp "${PROJECT_DIR}"/docs/*.md "${DOC_TARGET}/"
	cp "${PROJECT_DIR}/README.md" "${DOC_TARGET}/README.md" 2>/dev/null || true
fi
log "Dokumentation nach /usr/share/doc/sina-server kopiert"

# Hooks, Auto-Skripte und CLI ausfuehrbar machen (Git speichert keine
# Ausfuehrungsrechte auf allen Plattformen zuverlaessig).
chmod 0755 "${LB_DIR}/auto/config" \
	"${LB_DIR}"/config/hooks/live/*.hook.chroot \
	"${LB_DIR}/config/includes.chroot/usr/local/bin/sina" \
	"${LB_DIR}/config/includes.chroot/usr/local/bin/sina-serverd" \
	"${LB_DIR}/config/includes.chroot/usr/local/sbin/sina-installer"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Workaround fuer live-build 1:20230502
#
# binary_grub-efi dimensioniert das EFI-Image (efi.img) mit nur 55 KiB
# Reserve. Bei Ubuntu mit Secure Boot (shim-signed + grub-efi-amd64-signed)
# reicht das nicht: mcopy bricht mit "Disk full" ab. Die Reserve wird daher
# auf 4096 KiB erhoeht. Der Patch ist idempotent und bricht sofort ab, wenn
# das erwartete Muster in der installierten live-build-Version fehlt.
# ---------------------------------------------------------------------------
fix_live_build_efi_headroom() {
	local lb_script="/usr/lib/live/build/binary_grub-efi"

	if [ ! -f "${lb_script}" ]; then
		die "live-build-Skript ${lb_script} nicht gefunden."
	fi

	if grep -q 'size / 1024 + 4096' "${lb_script}"; then
		log "live-build: EFI-Reserve bereits auf 4096 KiB gesetzt"
		return 0
	fi

	if grep -q 'size / 1024 + 55' "${lb_script}"; then
		cp -a "${lb_script}" "${lb_script}.orig"
		sed -i 's|size / 1024 + 55|size / 1024 + 4096|' "${lb_script}"
		log "live-build: EFI-Reserve von 55 KiB auf 4096 KiB erhoeht (Workaround)"
		return 0
	fi

	die "Workaround passt nicht zu ${lb_script} - bitte live-build-Version pruefen."
}

log "Speicherplatz vor dem Build:"
df -h "${PROJECT_DIR}" || true

fix_live_build_efi_headroom

cd "${LB_DIR}"

log "Arbeitsverzeichnis bereinigen (lb clean --purge)"
lb clean --purge

log "Konfiguration erzeugen (lb config mit iso/auto/config)"
lb config

log "ISO bauen (lb build) - dies dauert je nach Verbindung 15 bis 40 Minuten"
if ! lb build --verbose; then
	die "lb build ist fehlgeschlagen. Letzte Zeilen des Protokolls:"
fi

# ---------------------------------------------------------------------------
# Ergebnis einsammeln
# ---------------------------------------------------------------------------
iso_source=''
for candidate in "${LB_DIR}"/*.hybrid.iso "${LB_DIR}"/*.iso; do
	if [ -f "${candidate}" ]; then
		iso_source=${candidate}
		break
	fi
done

[ -n "${iso_source}" ] || die "Es wurde keine ISO-Datei erzeugt (${LB_DIR}/*.iso)."

log "ISO gefunden: ${iso_source}"
mv -f "${iso_source}" "${DIST_DIR}/${ISO_NAME}"
chmod 0644 "${DIST_DIR}/${ISO_NAME}"

ISO_SIZE=$(stat -c %s "${DIST_DIR}/${ISO_NAME}")
log "ISO verschoben nach ${DIST_DIR}/${ISO_NAME} ($((ISO_SIZE / 1024 / 1024)) MiB)"

# ---------------------------------------------------------------------------
# Pruefen und Pruefsumme erzeugen
# ---------------------------------------------------------------------------
if [ "${VERIFY}" -eq 1 ]; then
	log "ISO validieren"
	"${PROJECT_DIR}/scripts/validate-iso.sh" "${DIST_DIR}/${ISO_NAME}"

	log "SHA256-Pruefsumme erzeugen"
	"${PROJECT_DIR}/scripts/generate-checksum.sh" "${DIST_DIR}/${ISO_NAME}"
fi

log "Build abgeschlossen: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "Ergebnis: ${DIST_DIR}/${ISO_NAME}"

# ---------------------------------------------------------------------------
# CI-Betrieb: Der Build laeuft als root (debootstrap/chroot), die spaeteren
# Workflow-Schritte laufen als normaler Benutzer. Deshalb werden die
# Ergebnisdateien an den aufrufenden Benutzer uebergeben (SUDO_UID/SUDO_GID),
# damit Pruefsumme, BUILD-INFO und Artifact-Upload ohne root schreiben koennen.
# ---------------------------------------------------------------------------
if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
	chown -R "${SUDO_UID}:${SUDO_GID}" "${DIST_DIR}" 2>/dev/null || true
	if [ -f "${LOG_FILE}" ]; then
		chown "${SUDO_UID}:${SUDO_GID}" "${LOG_FILE}" 2>/dev/null || true
	fi
	log "Ergebnisdateien an UID ${SUDO_UID}/GID ${SUDO_GID} uebergeben"
fi


