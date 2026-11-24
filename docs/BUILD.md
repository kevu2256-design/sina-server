# Sina Server 1.3.0 – Build-Dokumentation

Diese Dokumentation beschreibt, wie die bootfähige ISO von **Sina Server 1.3.0
(Standard Edition)** erzeugt wird – automatisch über GitHub Actions oder lokal
auf einem Linux-System.

| Eigenschaft | Wert |
| --- | --- |
| Produkt | Sina Server 1.3.0 Standard Edition |
| ISO-Datei | `Sina-Server-1.3.0-amd64.iso` |
| Prüfsumme | `Sina-Server-1.3.0-amd64.iso.sha256` (SHA256) |
| Artifact-Name | `Sina-Server-1.3.0-ISO` |
| Basis | Ubuntu 24.04 LTS (noble), amd64 |
| Bootloader | isolinux/syslinux (BIOS) + GRUB (UEFI, Secure Boot optional) |
| Build-Werkzeug | live-build `1:20230502` (Debian), per SHA256 geprüft |
| CI-Runner | `ubuntu-24.04` (GitHub-hosted) |

---

## 1. Aufbau des Repositories

```
.github/workflows/build-iso.yml      CI/CD-Pipeline (Build, Prüfung, Artifact, Release)
VERSION                              Einzige Quelle der Versionsnummer (1.3.0)

iso/                                 live-build-Projektverzeichnis
├── auto/config                      vollständige lb-config-Konfiguration
└── config/
    ├── package-lists/               Paketlisten für das Live-System
    ├── preseed/                     debconf-Antworten (Tastatur, Zeitzone, Locale)
    ├── bootloaders/                 eigenes isolinux-Bootmenü
    ├── hooks/live/                  Build-Hook (Dienste, Rechte, Syntaxprüfung)
    └── includes.chroot/             Dateien des Zielsystems
        ├── etc/sina/release         Release-/Build-Informationen
        ├── etc/NetworkManager/      NetworkManager-Konfiguration
        ├── etc/systemd/system/      sina-serverd.service, Autologin
        └── usr/local/               sina-CLI, sina-serverd, sina-installer

scripts/build-iso.sh                 Build-Ablauf (lb clean/config/build, ISO einsammeln)
scripts/validate-iso.sh              Prüfung der ISO (Bootfähigkeit, Inhalt, Prüfsumme)
scripts/generate-checksum.sh         SHA256-Prüfsummendatei erzeugen und gegenprüfen

docs/BUILD.md                        diese Datei
docs/INSTALLATION.md                 Installation und erste Schritte
```

Das Verzeichnis `iso/` ist ein vollständiges live-build-Projekt. `lb build`
führt dort automatisch `auto/config` aus; die Konfiguration ist damit auch ohne
GitHub Actions reproduzierbar.

---

## 2. Was im Image enthalten ist

| Bestandteil | Umsetzung |
| --- | --- |
| Ubuntu-LTS-Basis | `lb config --distribution noble --architecture amd64` |
| Kernel | `linux-image-generic` (`--linux-packages linux-image --linux-flavours generic`) |
| NetworkManager | Paket `network-manager` + `wpasupplicant`, `10-sina.conf`, Dienst aktiviert |
| sudo/Benutzerverwaltung | Pakete `sudo`, `adduser`, `passwd`; Live-Benutzer `sina` mit `sudo`-Gruppe |
| Sina-CLI | `/usr/local/bin/sina` (Status, Netzwerk, Benutzer, Dienste, Doctor, Update, Install) |
| Sina Server Dienst | `/usr/local/bin/sina-serverd` (Python, nur 127.0.0.1:8787), Unit `sina-serverd.service` |
| Installer (grafisch) | Calamares: `/etc/calamares/` (Einstellungen, Module, Branding `sina`), startet automatisch auf Konsole 1 |
| Installer (Text-Fallback) | `/usr/local/sbin/sina-installer` (Partitionierung, Kopie, GRUB, Benutzer) |
| Grafik-Basis | `xserver-xorg-core`, `xserver-xorg-input-libinput`, `xinit`, `openbox`, `fonts-dejavu-core` |
| GRUB/Boot | `--bootloaders "syslinux,grub-efi"`, `--uefi-secure-boot auto` |
| Live-System | `live-boot`, `live-config`, `live-config-systemd`, `--initramfs live-boot` |

---

## 2.1 Installations-Manager (Calamares)

Beim Booten des Live-Systems startet auf **Konsole 1** automatisch der grafische
Installer (`sina-setup.service` → `sina-setup-session` → `xinit` + Openbox →
`calamares`). Eine Shell bleibt auf **Konsole 2** (Strg+Alt+F2) erreichbar,
alternativ `sudo sina install --text`.

Ablauf im Installer: Sprache → Tastatur → Zeitzone → **Partitionierung**
(GPT, EFI-Systempartition unter `/boot/efi`, ext4, optional LUKS) → **Benutzer
und Passwort** (Mitglied der Gruppe `sudo`, optionales Autologin) → Zusammenfassung
→ Installation (Entpacken, GRUB für UEFI/BIOS, Dienste aktivieren) → Neustart.

| Datei | Zweck |
| --- | --- |
| `etc/calamares/settings.conf` | Reihenfolge der Seiten und Ausführungsschritte |
| `etc/calamares/modules/unpackfs.conf` | Quelle `/run/live/medium/live/filesystem.squashfs` (live-boot) |
| `etc/calamares/modules/partition.conf` | EFI-Partition `/boot/efi`, ext4, Swap-Auswahl |
| `etc/calamares/modules/users.conf` | Benutzer, `sudo`-Gruppe, Passwort-Mindestlänge 6, kein Root-Passwort |
| `etc/calamares/modules/services-systemd.conf` | aktiviert NetworkManager, `sina-serverd`, SSH, Zeitsynchronisation |
| `etc/calamares/modules/shellprocess_sina_cleanup.conf` | entfernt Live-Reste (Autologin, `/etc/sudoers.d/live`, `sina-setup`), erzeugt neue SSH-Hosts |
| `etc/calamares/modules/bootloader.conf` | GRUB-Installation, EFI-Verzeichnis `EFI/sina` |
| `etc/calamares/branding/sina/` | Branding (`branding.desc`, Logo/Begrüßungsbild ohne Fremdmarken) |

Alle Calamares-Konfigurationen werden im Build-Hook per `python3-yaml`
validiert; fehlerhaftes YAML bricht den Build ab. Die Bilder werden mit
`scripts/gen-branding.py` erzeugt (ohne externe Abhängigkeiten).

---

## 3. Pipeline: wann gebaut wird

`.github/workflows/build-iso.yml` wird ausgelöst durch:

| Auslöser | Bedingung | Ergebnis |
| --- | --- | --- |
| Manuell | Actions → „Sina Server ISO“ → *Run workflow* | ISO + Artifact |
| Push | Push auf `main` | ISO + Artifact |
| Tag | Push eines Tags `v*.*.*` (z. B. `v1.3.0`) | ISO + Artifact **und** GitHub Release |

Bei einem Tag prüft der Workflow zuerst, ob der Tag exakt zu `VERSION` passt
(`v1.3.0` ⇔ `VERSION` enthält `1.3.0`). Bei Abweichung bricht der Lauf mit einer
klaren Fehlermeldung ab, damit keine falsch benannte Version veröffentlicht wird.

Ablauf der Jobs:

1. **build** (`ubuntu-24.04`, Timeout 120 min)
   1. Repository auschecken, Version aus `VERSION` lesen
   2. Tag gegen `VERSION` prüfen (nur bei Tags)
   3. Speicherplatz auf dem Runner freiräumen
   4. Build-Abhängigkeiten installieren, live-build `1:20230502` per SHA256 prüfen
   5. `shellcheck` und Python-Syntaxprüfung als statische Qualitätsschranke
   6. `sudo -E bash scripts/build-iso.sh` – baut die ISO
   7. `scripts/validate-iso.sh … --require-efi` – prüft Bootfähigkeit und Inhalt
   8. `scripts/generate-checksum.sh` – erzeugt und verifiziert die SHA256-Datei
   9. `BUILD-INFO.txt` und `RELEASE-NOTES.md` erzeugen
   10. `Sina-Server-1.3.0-ISO` als Artifact hochladen
   11. Bei Fehlschlag: `build.log` als Artifact `…-build-log` hochladen
2. **release** (nur bei Tags, Rechte `contents: write`)
   1. Artifact herunterladen
   2. Prüfsumme erneut verifizieren (kein Release mit beschädigter ISO)
   3. `gh release create` mit ISO, `.sha256`, `BUILD-INFO.txt` und Release-Notizen

---

## 4. Versionierung

Die Version steht **nur** in der Datei `VERSION`. Sie wird verwendet für:

* `--iso-application "Sina Server <version> Standard Edition"`
* ISO-Volume-Label `SINA_SERVER_<version>_AMD64`
* Dateinamen `Sina-Server-<version>-amd64.iso(.sha256)`
* `/etc/sina/release` im Image (Anzeige über `sina version`)
* Artifact-Namen

Neue Version veröffentlichen:

```bash
echo "1.3.1" > VERSION          # Version erhöhen
git commit -am "Version 1.3.1"
git push origin main            # baut 1.3.1 als Artifact
git tag -a v1.3.1 -m "Sina Server 1.3.1"
git push origin v1.3.1          # baut 1.3.1 und erstellt das Release
```

Weitere Anpassungen sind nicht nötig – Workflow, Dateinamen und Release-Titel
leiten sich aus `VERSION` ab.

---

## 5. Lokaler Build (ohne GitHub)

Der Build benötigt **Linux** und **root-Rechte** (debootstrap und chroot).
Windows wird nicht unterstützt; nutze WSL2 mit Ubuntu 24.04 oder eine VM.

```bash
# 1. Repository an einen Pfad OHNE Leerzeichen klonen
#    (live-build bricht bei Leerzeichen im Pfad ab)
git clone <repository> ~/sina-server
cd ~/sina-server

# 2. Build-Abhängigkeiten
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  debootstrap xorriso squashfs-tools isolinux syslinux syslinux-common \
  syslinux-utils dosfstools mtools rsync file wget curl ca-certificates

# 3. live-build versioniert installieren (identisch zur Pipeline)
curl -fsSL -O http://deb.debian.org/debian/pool/main/l/live-build/live-build_20230502_all.deb
echo "a863905724e7b69d45066ebab113cb6de12a11984349847ad49f6151c10f017d  live-build_20230502_all.deb" \
  | sha256sum --check --strict
sudo apt-get install -y --no-install-recommends ./live-build_20230502_all.deb

# 4. Bauen (15–40 Minuten, ca. 6 GB freier Speicher)
sudo -E bash scripts/build-iso.sh

# 5. Ergebnis
ls -l dist/
#   Sina-Server-1.3.0-amd64.iso
#   Sina-Server-1.3.0-amd64.iso.sha256
```

Einzelne Schritte sind auch separat ausführbar:

```bash
bash scripts/validate-iso.sh dist/Sina-Server-1.3.0-amd64.iso --require-efi
bash scripts/generate-checksum.sh dist/Sina-Server-1.3.0-amd64.iso
sudo -E bash scripts/build-iso.sh --no-verify   # ohne Prüfung/Prüfsumme
```

**Wichtig:** Der Build muss im Linux-Dateisystem liegen (in WSL2 also z. B.
`~/sina-server`, nicht `/mnt/c/…`), weil live-build `mount`/`chroot` benötigt
und unter `/mnt/c` keine Linux-Rechte vorhanden sind.

---

## 6. Versionierte Build-Abhängigkeiten

| Komponente | Version | Herkunft |
| --- | --- | --- |
| live-build | `1:20230502` | Debian bookworm, `.deb` + SHA256 in der Pipeline geprüft |
| Ubuntu-Basis | `noble` (24.04 LTS) | `--distribution noble`, Mirror `archive.ubuntu.com` |
| Sicherheits-Mirror | `noble-security` | `security.ubuntu.com` |
| Kernel | `linux-image-generic` | Ubuntu-Archiv, jeweils aktuelle Version der Basis |
| CI-Runner | `ubuntu-24.04` | fest verdrahtet, nicht `ubuntu-latest` |

Warum Debian-live-build statt der Variante aus Ubuntu 24.04?
Ubuntu liefert `live-build 3.0~a57`, das ausschließlich ein BIOS-Boot-Image
(`boot/grub/grub_eltorito`) erzeugt. Debian-live-build `1:20230502` unterstützt
`--bootloaders "syslinux,grub-efi"` und `--uefi-secure-boot` und erzeugt damit
ein hybrides, UEFI- und BIOS-bootfähiges Abbild. Die Ubuntu-Pakete werden
weiterhin aus dem Ubuntu-Archiv bezogen (`ubuntu-keyring`,
`archive.ubuntu.com`).

Die apt-Indizes bleiben im Image (`--apt-indices true`): live-build installiert
in der Binary-Stage bei Bedarf `shim-signed`/`grub-efi-amd64-signed` für Secure
Boot nach. Ohne Indizes wäre das nicht möglich und Secure Boot würde ohne
Fehlermeldung deaktiviert.

**Angepasste Stelle im Build-Werkzeug:** `scripts/build-iso.sh` erhöht vor dem
Build die Reserve für das EFI-Image in `/usr/lib/live/build/binary_grub-efi`
von 55 KiB auf 4096 KiB (`fix_live_build_efi_headroom`). Ohne diese Anpassung
bricht `mcopy` bei Ubuntu-Paketen mit Secure-Boot-Dateien mit `Disk full` ab.
Der Patch ist idempotent, wird protokolliert und bricht sofort ab, wenn das
erwartete Muster in einer anderen live-build-Version fehlt.

---

## 7. Was `validate-iso.sh` prüft

| Prüfung | Art |
| --- | --- |
| Datei existiert, lesbar, ≥ 300 MiB | Fehler |
| ISO-9660-Signatur `CD001` an Offset 32769 | Fehler |
| `file(1)`-Erkennung als ISO-9660-Abbild | Warnung |
| Volume-Informationen lesbar, Label = Version | Fehler / Warnung |
| El-Torito-Bootkatalog vorhanden | Fehler |
| UEFI-Booteintrag vorhanden | Fehler mit `--require-efi`, sonst Warnung |
| GPT-Partitionstabelle (USB-Start) | Warnung |
| `/live/filesystem.squashfs` vorhanden | Fehler |
| Kernel und Initramfs vorhanden | Warnung |
| vorhandene `.sha256` stimmt | Fehler |

Die Pipeline ruft die Prüfung mit `--require-efi` auf: fehlt der UEFI-Eintrag,
schlägt der Build fehl und es wird kein Release erstellt.

---

## 8. Reproduzierbarkeit

* Die Build-Konfiguration liegt vollständig in `iso/auto/config` (keine
  impliziten Standardwerte der Build-Umgebung).
* `SOURCE_DATE_EPOCH` wird aus dem letzten Git-Commit abgeleitet; live-build
  verwendet den Wert für Dateizeitstempel im ISO.
* live-build wird exakt versioniert und per SHA256 geprüft.
* Die Paketversionen der Ubuntu-Basis sind nicht eingefroren (bewusste
  Entscheidung: Sicherheitsupdates sollen einfließen). Für einen byte-identischen
  Build müsste zusätzlich ein Snapshot des Ubuntu-Archivs verwendet werden
  (`SINA_MIRROR=http://snapshot.ubuntu.com/ubuntu/<zeitstempel>/`).

---

## 9. Fehlerbehebung

| Symptom | Ursache / Lösung |
| --- | --- |
| `Cannot build live image from a directory containing spaces` | Projektpfad enthält Leerzeichen → Repository nach `~/sina-server` klonen |
| `Skripte enthalten CRLF-Zeilenenden` | `dos2unix scripts/*.sh` bzw. `git config core.autocrlf false` und neu auschecken |
| `You need to install xy on your host system` | Abhängigkeit fehlt (Abschnitt 5) |
| `debootstrap` scheitert an der Signatur | `ubuntu-keyring` fehlt oder Mirror-URL falsch (`SINA_MIRROR`) |
| `No space left on device` | Speicher freiräumen; der Runner hat ca. 14 GB, der Build braucht ca. 6 GB |
| `Kein UEFI-Booteintrag` | GRUB-EFI-Stage fehlgeschlagen – Build-Log ab `Begin installing grub-efi` prüfen |
| `Permission denied` bei `dist/*.sha256` | `dist/` wurde vom `sudo`-Build als root erzeugt. `scripts/build-iso.sh` übergibt die Ergebnisdateien am Ende an `SUDO_UID`/`SUDO_GID`; lokale Builds ohne `sudo` sind nicht betroffen |
| `mcopy: Disk full` beim EFI-Image | live-build 20230502 reserviert nur 55 KiB für `efi.img`; mit Ubuntu-Secure-Boot-Dateien (shim + signierter GRUB) zu wenig. `scripts/build-iso.sh` erhöht die Reserve automatisch auf 4096 KiB (`fix_live_build_efi_headroom`) |
| `mksquashfs: Unrecognised compressor option -Xcompression-level` | `--chroot-squashfs-compression-level` entfernen – live-build erzeugt daraus eine Option, die `mksquashfs` nur für gzip kennt |
| Release-Job: `Resource not accessible by integration` | Job-Berechtigung `contents: write` fehlt (im Workflow gesetzt) |
| Artifact-Upload schlägt fehl (Speicherkontingent) | Die ISO ist ca. 1,5–2 GB. Bei privaten Repositories das Actions-Speicherkontingent beachten und ggf. `retention-days` in `.github/workflows/build-iso.yml` verringern |

Build-Protokoll: `build.log` im Projektverzeichnis (lokal) bzw. Artifact
`Sina-Server-1.3.0-build-log` (GitHub Actions).

---

## 10. Sicherheit

* Keine Passwörter, Tokens oder Schlüssel im Repository. Der Workflow benötigt
  keine Secrets; für das Release wird ausschließlich das automatisch erzeugte
  `GITHUB_TOKEN` mit minimalen Rechten (`contents: write`, nur im Release-Job)
  verwendet.
* Das Live-System meldet den Benutzer `sina` automatisch an der Konsole an und
  erlaubt `sudo` ohne Passwort – das ist das dokumentierte Standardverhalten von
  `live-config` für Live-Medien. Der Installer entfernt Autologin- und
  sudoers-Regeln und verlangt ein Passwort für den Administrator-Account.
* `sina-serverd` läuft als eigener Systembenutzer `sina-svc` mit
  `ProtectSystem=strict`, `PrivateTmp`, `NoNewPrivileges` und lauscht nur auf
  `127.0.0.1`.
* Externe Skripte werden nicht aus fremden Quellen ausgeführt; die einzige
  externe Binärquelle ist das geprüfte live-build-Paket (SHA256 im Workflow).
* Die ISO ist nicht signiert. Prüfsummen dienen der Integritätskontrolle; für
  eine Signatur müsste ein eigener Schlüssel als Secret hinterlegt werden.

---

## 11. Bekannte Grenzen

* Der Installer (`sina-installer`) partitioniert GPT mit BIOS-Boot-, EFI- und
  Root-Partition und kopiert das laufende Live-System. Er ist für einzelne
  Datenträger ausgelegt (kein LVM, keine Verschlüsselung, kein Dual-Boot).
* Secure Boot wird nur unterstützt, wenn `shim-signed`/`grub-efi-amd64-signed`
  im Ubuntu-Archiv verfügbar sind (`--uefi-secure-boot auto`). Andernfalls muss
  Secure Boot im BIOS deaktiviert werden.
* Die ISO ist ca. 1,5–2 GB groß (Kernel, Firmware, OpenSSH, Python).


