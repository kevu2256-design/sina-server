# Sina Server

**Sina Server 1.2.7 – Standard Edition** ist ein bootfähiges Server-Betriebssystem
auf Basis von **Ubuntu 24.04 LTS (noble, amd64)**. Die ISO wird vollständig
automatisch in GitHub Actions gebaut – ein lokales Linux ist dafür nicht
erforderlich.

| | |
| --- | --- |
| Version | `1.2.7` (Datei `VERSION`) |
| ISO | `Sina-Server-1.2.7-amd64.iso` |
| Prüfsumme | `Sina-Server-1.2.7-amd64.iso.sha256` |
| Artifact | `Sina-Server-1.2.7-ISO` |
| Start | UEFI (GRUB) und BIOS (isolinux) |

## Bestandteile des Images

* **Ubuntu 24.04 LTS** als Basis, Kernel `linux-image-generic`
* **NetworkManager** (Ethernet und WLAN) mit `nmcli`-Integration
* **sudo- und Benutzerverwaltung**, Administrator-Benutzer aus dem Installer
* **`sina`-CLI** – Status, Netzwerk, Benutzer, Dienste, Logs, Update, Installation
* **`sina-serverd`** – Control-API (JSON, nur `127.0.0.1:8787`), gehärtete Unit
* **`sina-installer`** – Installation vom Live-System auf einen Datenträger
* **GRUB** für UEFI (inkl. optionalem Secure Boot) und BIOS

## Build über GitHub Actions

| Auslöser | Ergebnis |
| --- | --- |
| Actions → *Sina Server ISO* → *Run workflow* | ISO als Artifact |
| Push auf `main` | ISO als Artifact |
| Tag `v1.2.7` | ISO als Artifact **und** GitHub Release |

Nach dem Lauf steht die ISO unter **Actions → Lauf → Artifacts →
`Sina-Server-1.2.7-ISO`** bereit.

## Lokaler Build

Siehe [docs/BUILD.md](docs/BUILD.md). Kurzfassung:

```bash
sudo apt-get install -y --no-install-recommends \
  debootstrap xorriso squashfs-tools isolinux syslinux syslinux-common \
  syslinux-utils dosfstools mtools rsync file wget curl ca-certificates
curl -fsSL -O http://deb.debian.org/debian/pool/main/l/live-build/live-build_20230502_all.deb
echo "a863905724e7b69d45066ebab113cb6de12a11984349847ad49f6151c10f017d  live-build_20230502_all.deb" | sha256sum --check --strict
sudo apt-get install -y --no-install-recommends ./live-build_20230502_all.deb
sudo -E bash scripts/build-iso.sh
```

## Struktur

```
.github/workflows/build-iso.yml   CI/CD-Pipeline
VERSION                           Versionsnummer (einzige Quelle)
iso/                              live-build-Projekt (auto/config, config/…)
scripts/build-iso.sh              Build
scripts/validate-iso.sh           ISO-Prüfung
scripts/generate-checksum.sh      SHA256-Prüfsumme
docs/BUILD.md                     Build-Dokumentation
docs/INSTALLATION.md              Installation und erste Schritte
```

## Installation

Siehe [docs/INSTALLATION.md](docs/INSTALLATION.md): ISO herunterladen,
Prüfsumme kontrollieren, USB-Stick schreiben, booten, Live-System starten und mit
`sudo sina install` auf einen Datenträger installieren.

## Sicherheit

* Keine Passwörter oder Tokens im Repository; der Workflow nutzt nur das
  automatische `GITHUB_TOKEN` mit minimalen Rechten.
* live-build wird versioniert und per SHA256 geprüft installiert.
* Der Control-Dienst läuft als eigener Systembenutzer mit systemd-Härtung und
  lauscht nur lokal.

## Lizenz und Basis

Die enthaltenen Ubuntu-Pakete unterliegen den jeweiligen Ubuntu-/Debian-Lizenzen.
