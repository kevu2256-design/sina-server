# Sina Server 1.2.7 – Installation

Diese Anleitung beschreibt Download, Prüfung, Start und Installation von
**Sina Server 1.2.7 (Standard Edition)**.

| Eigenschaft | Wert |
| --- | --- |
| Datei | `Sina-Server-1.2.7-amd64.iso` (ca. 1,5–2 GB) |
| Prüfsumme | `Sina-Server-1.2.7-amd64.iso.sha256` |
| Architektur | amd64 (x86-64) |
| Start | UEFI und BIOS/Legacy |
| Live-Benutzer | `sina` (automatische Anmeldung an der Konsole) |

---

## 1. Voraussetzungen

* USB-Stick mit mindestens 4 GB (Inhalt wird gelöscht)
* Zielsystem: 64-Bit-PC, mindestens 2 GB RAM, mindestens 8 GB Datenträger
* Für die Installation: Zugriff auf Tastatur und Bildschirm (die Installation
  erfolgt textbasiert auf der Konsole)

---

## 2. ISO herunterladen

**Variante A – GitHub Actions (Entwicklungsbuild):**

1. Repository → *Actions* → Workflow **Sina Server ISO** → gewünschter Lauf
2. Abschnitt *Artifacts* → `Sina-Server-1.2.7-ISO` herunterladen
3. Archiv entpacken; enthalten sind
   * `Sina-Server-1.2.7-amd64.iso`
   * `Sina-Server-1.2.7-amd64.iso.sha256`
   * `BUILD-INFO.txt`

**Variante B – GitHub Release (veröffentlichter Stand):**

Repository → *Releases* → `v1.2.7` → Dateien herunterladen.

---

## 3. Prüfsumme kontrollieren

Die Prüfsummendatei enthält Hash und Dateinamen:

```
<sha256>  Sina-Server-1.2.7-amd64.iso
```

**Linux:**

```bash
cd <download-verzeichnis>
sha256sum -c Sina-Server-1.2.7-amd64.iso.sha256
# Erwartete Ausgabe: Sina-Server-1.2.7-amd64.iso: OK
```

**macOS:**

```bash
cd <download-verzeichnis>
shasum -a 256 -c Sina-Server-1.2.7-amd64.iso.sha256
```

**Windows (PowerShell):**

```powershell
Get-FileHash .\Sina-Server-1.2.7-amd64.iso -Algorithm SHA256
# Hash mit dem Inhalt von Sina-Server-1.2.7-amd64.iso.sha256 vergleichen
```

Stimmt die Prüfsumme nicht, die Datei erneut herunterladen – nicht verwenden.

---

## 4. USB-Stick erstellen

**Windows – Rufus:**

1. Rufus starten, USB-Stick wählen
2. *Startart* → ISO-Abbild → `Sina-Server-1.2.7-amd64.iso`
3. Partitionsschema: *GPT* (für UEFI) bzw. *MBR* (für reine BIOS-Systeme)
4. *Start* → Datenverlust bestätigen

**Windows/macOS/Linux – balenaEtcher:** ISO auswählen, Stick auswählen, *Flash*.

**Linux – dd (Vorsicht: Zielgerät prüfen!):**

```bash
lsblk                                  # Zielgerät ermitteln, z. B. /dev/sdX
sudo dd if=Sina-Server-1.2.7-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

---

## 5. Vom USB-Stick booten

1. Stick einstecken, Rechner starten
2. Bootmenü öffnen (je nach Hersteller `F12`, `F11`, `F9`, `ESC`)
3. Den USB-Stick im **UEFI-Modus** (empfohlen) oder Legacy/BIOS-Modus wählen
4. Bootmenü der ISO:
   * **Sina Server starten** (Standard, startet nach 10 Sekunden automatisch)
   * **Sina Server starten (abgesicherter Modus)** – ohne Grafik-/Treibertuning

**Secure Boot:** Das Abbild wird mit GRUB gebaut; signierte Shim-/GRUB-Pakete
werden eingebunden, wenn sie im Ubuntu-Archiv verfügbar sind. Startet das System
trotzdem nicht, Secure Boot im BIOS/UEFI vorübergehend deaktivieren.

---

## 6. Live-System bedienen

Nach dem Start wird `sina` an der Konsole automatisch angemeldet. Prüfen:

```bash
sina version      # Produkt, Edition, Basis, Build-Informationen
sina status       # Dienste, Netzwerk, Ressourcen
sina doctor       # Prüfliste mit OK/WARN/FEHL
```

Netzwerk (NetworkManager):

```bash
sina net status                 # Zustand von NetworkManager und Schnittstellen
sina net wifi                   # WLAN-Netze suchen
sudo sina net connect "MeinWLAN"  # Passwort wird interaktiv abgefragt
```

> Die Live-Sitzung arbeitet ohne Passwort (automatische Anmeldung, `sudo` ohne
> Passwort). Das ist bei Live-Medien üblich – das System ist während der
> Live-Sitzung nicht gegen physischen Zugriff geschützt.

Weitere Befehle: `sina help`.

---

## 7. Auf einen Datenträger installieren

> **Achtung:** Der gewählte Datenträger wird vollständig gelöscht. Vorher alle
> Daten sichern. Die Installation ersetzt vorhandene Betriebssysteme
> (kein Dual-Boot).

```bash
sudo sina install
```

Ablauf des Installers (`sina-installer`):

1. **Datenträger wählen:** verfügbare Datenträger werden aufgelistet; Name
   eingeben (z. B. `sda` oder `nvme0n1`). Zur Bestätigung muss `JA` getippt
   werden. Der laufende USB-Stick kann nicht Ziel sein und wird abgelehnt.
2. **Partitionierung (GPT):**
   * Partition 1: 1 MiB BIOS-Boot-Partition (GRUB im BIOS-Modus)
   * Partition 2: 512 MiB EFI-Systempartition (FAT32)
   * Partition 3: restlicher Platz als ext4-Wurzeldateisystem
3. **Dateisysteme** werden formatiert und eingebunden.
4. **Kopie:** das laufende Live-System wird auf den Datenträger kopiert
   (`rsync`, inklusive Rechte, ACLs und xattrs).
5. **Grundkonfiguration:**
   * Hostname (Standard: `sina-server`)
   * Administrator-Benutzer (Standard: `sina`) inkl. Passwortvergabe
   * `root`-Konto wird gesperrt (`sudo` wird verwendet)
   * `fstab` mit UUIDs, `/etc/hosts`, `/etc/resolv.conf`
6. **GRUB** wird für UEFI (`EFI/Sina` und Fallback `EFI/BOOT/BOOTX64.EFI`) und
   BIOS installiert; `update-grub` erzeugt die Konfiguration.
7. **Abschluss:** Autologin und Live-sudoers-Regel werden entfernt, neue
   `machine-id`, neue SSH-Hostschlüssel, Initramfs neu erzeugt, Datenträger
   ausgehängt.

Zum Abschluss:

```bash
sudo reboot
```

USB-Stick entfernen und im BIOS/UEFI den installierten Datenträger als
Startmedium wählen.

---

## 8. Erster Start des installierten Systems

1. Anmeldung mit dem im Installer angelegten Benutzer und Passwort
2. System aktualisieren:

   ```bash
   sudo apt-get update
   sudo apt-get -y dist-upgrade
   ```

   oder komfortabel: `sudo sina update`
3. Zustand prüfen:

   ```bash
   sina version
   sina doctor
   ```

4. Netzwerk einrichten (falls nicht per DHCP automatisch geschehen):

   ```bash
   sudo sina net status
   sudo sina net connect "MeinWLAN"
   ```

5. Optionaler Fernzugriff per SSH:

   ```bash
   sudo systemctl status ssh
   ip -brief address show          # IP-Adresse ermitteln
   ```

   Der SSH-Dienst ist installiert und aktiv; Passwortanmeldung ist für Benutzer
   mit gesetztem Passwort möglich. Für Server empfiehlt sich die Anmeldung per
   Schlüssel:

   ```bash
   ssh-keygen -t ed25519
   ssh-copy-id benutzer@<server-ip>
   ```

---

## 9. Der Dienst `sina-serverd`

Der Control-Dienst der Sina Server Edition läuft nach der Installation
automatisch und lauscht ausschließlich lokal auf `127.0.0.1:8787`:

```bash
curl http://127.0.0.1:8787/health    # {"status": "ok", ...}
curl http://127.0.0.1:8787/version   # Versions- und Build-Informationen
curl http://127.0.0.1:8787/status    # Systemstatus als JSON
```

Verwaltung:

```bash
sina service status
sudo sina service restart sina-serverd
sina logs -f
```

Der Dienst läuft als Systembenutzer `sina-svc` mit `ProtectSystem=strict` und
ohne Schreibrechte außerhalb von `/var/lib/sina` und `/var/log/sina`. Soll die
API von außen erreichbar sein, dies bewusst über einen Reverse Proxy (z. B.
Caddy oder nginx) mit TLS absichern, statt den Dienst direkt zu öffnen.

---

## 10. Benutzerverwaltung

```bash
sina user list                       # Benutzer mit UID >= 1000
sudo sina user add max --admin       # Benutzer anlegen, Passwort abfragen, sudo-Rechte
sina user groups max
```

Der erste Benutzer aus dem Installer ist Mitglied der Gruppe `sudo` und darf
`sudo` verwenden.

---

## 11. Fehlerbehebung

| Problem | Lösung |
| --- | --- |
| Rechner startet nicht vom USB-Stick | Bootmenü erneut öffnen, UEFI- und Legacy-Modus testen, Stick neu schreiben |
| „Security Violation“ / Secure Boot | Secure Boot deaktivieren oder Schlüssel im BIOS zurücksetzen |
| Kein Netzwerk im Live-System | `sina net status`; bei WLAN `sina net wifi`, dann `sudo sina net connect "<SSID>"` |
| WLAN wird nicht gefunden | `sudo rfkill unblock wifi`, erneut `sina net wifi` |
| Installation bricht ab | Meldung notieren; Datenträger muss ≥ 8 GB haben und darf nicht eingebunden sein |
| Nach der Installation kein Start | Im BIOS/UEFI den Eintrag „Sina“ wählen; alternativ den Fallback `EFI/BOOT/BOOTX64.EFI` |
| Passwort vergessen | Live-Medium starten, installiertes System einbinden und `chroot` verwenden (Rettungsmodus) |
| `sina doctor` meldet Dienstfehler | `sudo journalctl -u sina-serverd -n 100 --no-pager` |

---

## 12. Deinstallation

Sina Server belegt den gesamten gewählten Datenträger. Eine Deinstallation
erfolgt durch Neuinstallation eines anderen Systems oder durch Zurücksetzen des
Datenträgers (z. B. mit einem Partitionierungswerkzeug). Es werden keine Daten
außerhalb des Ziel-Datenträgers verändert.

