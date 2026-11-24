# Sina Server

**Sina Server 1.3.0 – Standard Edition** ist ein bootfähiges Server-Betriebssystem
auf Basis von **Ubuntu 24.04 LTS (noble, amd64)**. Die ISO wird vollständig
automatisch in GitHub Actions gebaut – ein lokales Linux ist dafür nicht
erforderlich.

| | |
| --- | --- |
| Version | `1.3.0` (Datei `VERSION`) |
| ISO | `Sina-Server-1.3.0-amd64.iso` |
| Prüfsumme | `Sina-Server-1.3.0-amd64.iso.sha256` |
| Artifact | `Sina-Server-1.3.0-ISO` |
| Start | UEFI (GRUB) und BIOS (isolinux) |

## Bestandteile des Images

* **Ubuntu 24.04 LTS** als Basis, Kernel `linux-image-generic`
* **NetworkManager** (Ethernet und WLAN) mit `nmcli`-Integration
* **sudo- und Benutzerverwaltung**, Administrator-Benutzer aus dem Installer
* **`sina`-CLI** – Status, Netzwerk, Benutzer, Dienste, Logs, Update, Installation
* **`sina-serverd`** – Control-API (JSON, nur `127.0.0.1:8787`), gehärtete Unit
* **Grafischer Installations-Manager (Calamares)** – Sprache, Tastatur, Zeitzone,
  Partitionierung (GPT, EFI, optional LUKS) sowie **Benutzer und Passwort**;
  startet beim Booten automatisch. Text-Fallback: `sudo sina install --text`
* **`sina-installer`** – textbasierter Installer (Fallback, z. B. per SSH)
* **GRUB** für UEFI (inkl. optionalem Secure Boot) und BIOS

## Build über GitHub Actions

| Auslöser | Ergebnis |
| --- | --- |
| Actions → *Sina Server ISO* → *Run workflow* | ISO als Artifact |
| Push auf `main` | ISO als Artifact |
| Tag `v1.3.0` | ISO als Artifact **und** GitHub Release |

Nach dem Lauf steht die ISO unter **Actions → Lauf → Artifacts →
`Sina-Server-1.3.0-ISO`** bereit.

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
Prüfsumme kontrollieren, USB-Stick schreiben, booten. Der grafische
Installations-Manager startet automatisch und führt durch Partitionierung,
Benutzeranlage und Passwortvergabe.

## Branding

Das laufende System ist vollständig als **Sina Server** gebrandet: `os-release`,
`lsb-release`, Bootmenü (GRUB-Eintrag „Sina Server"), Installer (Calamares) und
Kommandozeilenwerkzeuge zeigen keinen Fremdmarken-Namen. Die technische Basis
(Ubuntu-Paketquelle, `noble`) ist nur dort sichtbar, wo sie für Wartung und
Build nötig ist (z. B. `dpkg -l`, Paketquellen).

## Sicherheit
* Keine Passwörter oder Tokens im Repository; der Workflow nutzt nur das
  automatische `GITHUB_TOKEN` mit minimalen Rechten.
* live-build wird versioniert und per SHA256 geprüft installiert.
* Der Control-Dienst läuft als eigener Systembenutzer mit systemd-Härtung und
  lauscht nur lokal.

## Lizenz und Basis

Die enthaltenen Ubuntu-Pakete unterliegen den jeweiligen Ubuntu-/Debian-Lizenzen.
