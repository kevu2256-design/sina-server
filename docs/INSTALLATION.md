# Sina Server 1.3.0 – Installation

Diese Anleitung beschreibt Download, Prüfung, Start und Installation von
**Sina Server 1.3.0 (Standard Edition)**.

| Eigenschaft | Wert |
| --- | --- |
| Datei | `Sina-Server-1.3.0-amd64.iso` (ca. 1,5–2 GB) |
| Prüfsumme | `Sina-Server-1.3.0-amd64.iso.sha256` |
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
2. Abschnitt *Artifacts* → `Sina-Server-1.3.0-ISO` herunterladen
3. Archiv entpacken; enthalten sind
   * `Sina-Server-1.3.0-amd64.iso`
   * `Sina-Server-1.3.0-amd64.iso.sha256`
   * `BUILD-INFO.txt`

**Variante B – GitHub Release (veröffentlichter Stand):**

Repository → *Releases* → `v1.3.0` → Dateien herunterladen.

---

## 3. Prüfsumme kontrollieren

Die Prüfsummendatei enthält Hash und Dateinamen:

```
<sha256>  Sina-Server-1.3.0-amd64.iso
```

**Linux:**

```bash
cd <download-verzeichnis>
sha256sum -c Sina-Server-1.3.0-amd64.iso.sha256
# Erwartete Ausgabe: Sina-Server-1.3.0-amd64.iso: OK
```

**macOS:**

```bash
cd <download-verzeichnis>
shasum -a 256 -c Sina-Server-1.3.0-amd64.iso.sha256
```

**Windows (PowerShell):**

```powershell
Get-FileHash .\Sina-Server-1.3.0-amd64.iso -Algorithm SHA256
# Hash mit dem Inhalt von Sina-Server-1.3.0-amd64.iso.sha256 vergleichen
```

Stimmt die Prüfsumme nicht, die Datei erneut herunterladen – nicht verwenden.

---

## 4. USB-Stick erstellen

**Windows – Rufus:**

1. Rufus starten, USB-Stick wählen
2. *Startart* → ISO-Abbild → `Sina-Server-1.3.0-amd64.iso`
3. Partitionsschema: *GPT* (für UEFI) bzw. *MBR* (für reine BIOS-Systeme)
4. *Start* → Datenverlust bestätigen

**Windows/macOS/Linux – balenaEtcher:** ISO auswählen, Stick auswählen, *Flash*.

**Linux – dd (Vorsicht: Zielgerät prüfen!):**

```bash
lsblk                                  # Zielgerät ermitteln, z. B. /dev/sdX
sudo dd if=Sina-Server-1.3.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
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
werden eingebunden, wenn signierte Shim-/GRUB-Pakete in der Paketquelle verfügbar sind. Startet das System
trotzdem nicht, Secure Boot im BIOS/UEFI vorübergehend deaktivieren.

---

## 6. Live-System und Installations-Manager

Nach dem Start erscheint auf **Konsole 1** automatisch der grafische
Installations-Manager (Calamares). Er fuehrt durch Sprache, Tastatur, Zeitzone,
Partitionierung sowie Benutzer- und Passwortvergabe.

Zusaetzlich steht eine Shell auf **Konsole 2** bereit: `Strg+Alt+F2`
(Anmeldung als Benutzer `sina`).

Dort stehen die Sina-Befehle zur Verfuegung:

```bash
sina version      # Produkt, Edition, Basis, Build-Informationen
sina status       # Dienste, Netzwerk, Ressourcen
sina doctor       # Pruefliste mit OK/WARN/FEHL
```

Netzwerk (NetworkManager):

```bash
sina net status                 # Zustand von NetworkManager und Schnittstellen
sina net wifi                   # WLAN-Netze suchen
sudo sina net connect "MeinWLAN"  # Passwort wird interaktiv abgefragt
```

> Die Live-Sitzung arbeitet ohne Passwort (automatische Anmeldung). Das ist bei
> Live-Medien ueblich; die Installation vergibt einen eigenen Benutzer mit
> Passwort.

## 7. Installation auf einen Datenträger

> **Achtung:** Der gewählte Datenträger wird vollständig gelöscht. Vorher
> alle Daten sichern. Die Installation ersetzt vorhandene Betriebssysteme
> (kein Dual-Boot).

Der Installer startet automatisch. Manuell (z. B. nach Abbruch) starten mit:

```bash
sudo sina install           # grafischer Installer
sudo sina install --text    # textbasierter Installer (Fallback, z. B. per SSH)
```

Seiten des grafischen Installers:

1. **Willkommen** – Systemprüfung (RAM, Datenträger, Rechte), Sprachauswahl
2. **Ort und Zeitzone** – Region/Zeitzone, Sprachpakete
3. **Tastatur** – Layout (Standard: Deutsch), Testfeld
4. **Partitionierung**
   * *Datenträger löschen und installieren* (empfohlen): GPT mit
     EFI-Systempartition unter `/boot/efi` (300 MiB) und ext4-Wurzeldateisystem
   * *Manuell partitionieren*, optional verschlüsselt (LUKS)
   * Swap: keine / kleine Partition / Auslagerungsdatei
5. **Benutzer und Passwort**
   * Vollständiger Name, Benutzername, Hostname
   * Passwort (mindestens 6 Zeichen) und Wiederholung
   * Der Benutzer ist Mitglied der Gruppe `sudo`; das `root`-Konto bleibt gesperrt
6. **Zusammenfassung** – alle Angaben prüfen, dann *Installieren*
7. **Installation** – Live-Dateisystem entpacken, GRUB für UEFI und BIOS
   installieren, Dienste aktivieren, Live-Reste entfernen
8. **Fertig** – Neustart (Medium entfernen)

Dauer: je nach Datenträger etwa 5 bis 15 Minuten.

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

