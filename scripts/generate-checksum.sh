#!/bin/bash
# ---------------------------------------------------------------------------
# generate-checksum.sh - Erzeugt SHA256-Pruefsummendateien fuer Build-Artefakte
#
# Ergebnis je Datei: <datei>.sha256 mit dem Inhalt
#   <sha256>  <dateiname>
# (Dateiname ohne Pfad, damit "sha256sum -c" im Zielverzeichnis funktioniert.)
#
# Verwendung:
#   generate-checksum.sh dist/Sina-Server-1.2.7-amd64.iso
#   generate-checksum.sh                      # alle dist/*.iso
# ---------------------------------------------------------------------------
set -Eeuo pipefail

PROGRAM=${0##*/}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)

log() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() {
	printf '\033[31mFEHLER:\033[0m %s\n' "$*" >&2
	exit 1
}

command -v sha256sum >/dev/null 2>&1 || die "sha256sum (coreutils) ist nicht verfuegbar."

files=()
for arg in "$@"; do
	case "${arg}" in
		-h|--help)
			printf 'Aufruf: %s [datei ...]\n' "${PROGRAM}"
			exit 0
			;;
		-*) die "Unbekannte Option: ${arg}" ;;
		*) files+=("${arg}") ;;
	esac
done

if [ "${#files[@]}" -eq 0 ]; then
	shopt -s nullglob
	for candidate in "${PROJECT_DIR}"/dist/*.iso; do
		files+=("${candidate}")
	done
	shopt -u nullglob
fi

[ "${#files[@]}" -gt 0 ] || die "Keine ISO-Dateien gefunden (dist/*.iso)."

for file in "${files[@]}"; do
	[ -f "${file}" ] || die "Datei existiert nicht: ${file}"

	dir=$(CDPATH='' cd -- "$(dirname -- "${file}")" && pwd)
	base=$(basename -- "${file}")
	checksum_file="${dir}/${base}.sha256"

	log "Pruefsumme fuer ${base} erzeugen"
	(
		cd "${dir}"
		sha256sum -- "${base}" >"${checksum_file}.tmp"
		mv "${checksum_file}.tmp" "${checksum_file}"
	)

	# Unmittelbare Gegenprobe: schlaegt fehl, wenn die Datei nicht lesbar ist
	(
		cd "${dir}"
		sha256sum --check --status "${base}.sha256"
	) || die "Pruefsumme konnte nicht verifiziert werden: ${checksum_file}"

	printf '  Datei:    %s\n' "${file}"
	printf '  Pruefsumme: %s\n' "$(cut -d' ' -f1 "${checksum_file}")"
	printf '  Ablage:   %s\n' "${checksum_file}"
done

log "Pruefsummendateien erstellt"
