#!/bin/bash
# ---------------------------------------------------------------------------
# validate-iso.sh - Prueft eine gebaute Sina-Server-ISO auf Bootfaehigkeit
#
# Geprueft werden:
#   * Existenz, Lesbarkeit und Mindestgroesse
#   * ISO-9660-Signatur ("CD001" an Offset 32769)
#   * El-Torito-Bootkatalog (BIOS) und EFI-Eintrag
#   * Hybrid-Image (GPT/Partitionierung fuer USB-Sticks)
#   * Inhalt: Kernel, Initramfs und squashfs-Dateisystem
#   * optionale SHA256-Pruefsummendatei neben der ISO
#
# Verwendung: validate-iso.sh <iso-datei> [--require-efi] [--min-size MB]
# ---------------------------------------------------------------------------
set -Eeuo pipefail

PROGRAM=${0##*/}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
MIN_SIZE_MB=300
REQUIRE_EFI=0
ISO=''

log() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() {
	printf '\033[31mFEHLER:\033[0m %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<EOF
Aufruf: ${PROGRAM} <iso-datei> [--require-efi] [--min-size MB]

  --require-efi   Build schlaegt fehl, wenn kein EFI-Booteintrag vorhanden ist
  --min-size MB   Mindestgroesse der ISO in MiB (Standard: ${MIN_SIZE_MB})
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--require-efi) REQUIRE_EFI=1 ;;
		--min-size)
			shift
			[ $# -gt 0 ] || die "--min-size benoetigt einen Wert in MiB."
			MIN_SIZE_MB=$1
			;;
		-h|--help) usage; exit 0 ;;
		-*) usage >&2; die "Unbekannte Option: $1" ;;
		*) ISO=$1 ;;
	esac
	shift
done

[ -n "${ISO}" ] || die "Keine ISO-Datei angegeben. Aufruf: ${PROGRAM} <iso-datei>"

FAILURES=0
WARNINGS=0

ok() { printf '  \033[32m[ OK ]\033[0m   %s\n' "$*"; }
warn() {
	printf '  \033[33m[WARN]\033[0m   %s\n' "$*"
	WARNINGS=$((WARNINGS + 1))
}
fail() {
	printf '  \033[31m[FEHL]\033[0m   %s\n' "$*"
	FAILURES=$((FAILURES + 1))
}

log "ISO pruefen: ${ISO}"

# --- Existenz und Groesse --------------------------------------------------
if [ ! -e "${ISO}" ]; then
	die "Datei existiert nicht: ${ISO}"
fi
[ -f "${ISO}" ] || die "Kein regulaere Datei: ${ISO}"
[ -r "${ISO}" ] || die "Datei ist nicht lesbar: ${ISO}"

SIZE_BYTES=$(stat -c %s "${ISO}")
SIZE_MB=$((SIZE_BYTES / 1024 / 1024))
if [ "${SIZE_MB}" -ge "${MIN_SIZE_MB}" ]; then
	ok "Datei vorhanden, ${SIZE_MB} MiB (Minimum ${MIN_SIZE_MB} MiB)"
else
	fail "ISO ist mit ${SIZE_MB} MiB kleiner als die Mindestgroesse von ${MIN_SIZE_MB} MiB"
fi

# --- ISO-9660-Signatur -----------------------------------------------------
MAGIC=$(dd if="${ISO}" bs=1 skip=32769 count=5 status=none 2>/dev/null | tr -d '\0' || true)
if [ "${MAGIC}" = "CD001" ]; then
	ok "ISO-9660-Signatur gefunden (CD001)"
else
	fail "Keine ISO-9660-Signatur an Offset 32769 (gefunden: '${MAGIC}')"
fi

# --- Dateityp --------------------------------------------------------------
if command -v file >/dev/null 2>&1; then
	FILE_TYPE=$(file -b "${ISO}")
	printf '  \033[2mDateityp: %s\033[0m\n' "${FILE_TYPE}"
	case "${FILE_TYPE}" in
		*ISO\ 9660*) ok "file(1) erkennt ein ISO-9660-Abbild" ;;
		*) warn "file(1) erkennt kein ISO-9660-Abbild" ;;
	esac
fi

command -v xorriso >/dev/null 2>&1 || die "xorriso wird zur Pruefung benoetigt."

# --- Volume-Informationen --------------------------------------------------
PVD_INFO=$(xorriso -indev "${ISO}" -pvd_info 2>/dev/null || true)
if [ -n "${PVD_INFO}" ]; then
	ok "ISO-Volume-Informationen lesbar"
	printf '%s\n' "${PVD_INFO}" | head -n 6 | sed 's/^/    /'

	if [ -r "${PROJECT_DIR}/VERSION" ]; then
		EXPECTED_VERSION=$(tr -d ' \t\r\n' <"${PROJECT_DIR}/VERSION")
		EXPECTED_VOLUME="SINA_SERVER_$(printf '%s' "${EXPECTED_VERSION}" | tr '.' '_')_AMD64"
		if printf '%s\n' "${PVD_INFO}" | grep -q "${EXPECTED_VOLUME}"; then
			ok "Volume-Label entspricht der Version (${EXPECTED_VOLUME})"
		else
			warn "Volume-Label passt nicht zur erwarteten Version (${EXPECTED_VOLUME})"
		fi
	fi
else
	fail "Volume-Informationen konnten nicht gelesen werden"
fi

# --- El-Torito-Booteintraege ----------------------------------------------
EL_TORITO=$(xorriso -indev "${ISO}" -report_el_torito plain 2>/dev/null || true)
BIOS_ENTRIES=$(printf '%s\n' "${EL_TORITO}" | grep -c 'El Torito boot img' || true)
EFI_ENTRIES=$(printf '%s\n' "${EL_TORITO}" | grep -c 'UEFI' || true)

if [ "${BIOS_ENTRIES}" -ge 1 ]; then
	ok "El-Torito-Bootkatalog mit ${BIOS_ENTRIES} Eintraegen vorhanden"
else
	fail "Kein El-Torito-Booteintrag gefunden - ISO ist nicht bootfaehig"
fi

if [ "${EFI_ENTRIES}" -ge 1 ]; then
	ok "UEFI-Booteintrag vorhanden (${EFI_ENTRIES})"
elif [ "${REQUIRE_EFI}" -eq 1 ]; then
	fail "Kein UEFI-Booteintrag gefunden (--require-efi)"
else
	warn "Kein UEFI-Booteintrag gefunden (BIOS-Start bleibt moeglich)"
fi

# --- Hybrid-Image / Systembereich -----------------------------------------
SYSTEM_AREA=$(xorriso -indev "${ISO}" -report_system_area plain 2>/dev/null || true)
if printf '%s\n' "${SYSTEM_AREA}" | grep -qi 'gpt'; then
	ok "Hybrides Abbild mit GPT-Partitionstabelle (USB-Start)"
else
	warn "Keine GPT-Partitionstabelle erkannt (Start von USB eventuell eingeschraenkt)"
fi

# --- Inhalt des Live-Dateisystems -----------------------------------------
LIVE_LISTING=$(xorriso -indev "${ISO}" -ls /live/ 2>/dev/null || true)
if [ -z "${LIVE_LISTING}" ]; then
	LIVE_LISTING=$(xorriso -indev "${ISO}" -find / -name filesystem.squashfs 2>/dev/null || true)
fi

if printf '%s\n' "${LIVE_LISTING}" | grep -q 'filesystem\.squashfs'; then
	ok "Live-Dateisystem /live/filesystem.squashfs enthalten"
else
	fail "filesystem.squashfs fehlt im Abbild"
fi

if printf '%s\n' "${LIVE_LISTING}" | grep -Eq 'vmlinuz'; then
	ok "Kernel (vmlinuz) enthalten"
else
	warn "Kein Kernel im Verzeichnis /live gefunden"
fi

if printf '%s\n' "${LIVE_LISTING}" | grep -Eq 'initrd'; then
	ok "Initramfs (initrd.img) enthalten"
else
	warn "Keine Initramfs im Verzeichnis /live gefunden"
fi

# --- Pruefsummendatei (falls bereits vorhanden) ---------------------------
CHECKSUM_FILE="${ISO}.sha256"
if [ -f "${CHECKSUM_FILE}" ]; then
	if (cd "$(dirname "${ISO}")" && sha256sum -c "$(basename "${CHECKSUM_FILE}")" >/dev/null 2>&1); then
		ok "SHA256-Pruefsumme stimmt mit ${CHECKSUM_FILE} ueberein"
	else
		fail "SHA256-Pruefsumme stimmt nicht mit ${CHECKSUM_FILE} ueberein"
	fi
fi

# --- Ergebnis -------------------------------------------------------------
printf '\n'
if [ "${FAILURES}" -gt 0 ]; then
	printf '\033[31mPruefung fehlgeschlagen: %d Fehler, %d Warnungen\033[0m\n' \
		"${FAILURES}" "${WARNINGS}"
	exit 1
fi
printf '\033[32mPruefung erfolgreich: 0 Fehler, %d Warnungen\033[0m\n' "${WARNINGS}"

