# MonitorTools CLI - Benutzerhandbuch

## Übersicht

MonitorTools ist ein Windows-Kommandozeilenwerkzeug zur Steuerung von Monitoren über DDC/CI (Display Data Channel Command Interface). Es ermöglicht das Abfragen und Setzen von Monitor-Einstellungen wie Helligkeit, Kontrast, Lautstärke und Eingabequellen.

## Systemvoraussetzungen

- Windows 11
- .NET 10.0 (SDK 10.0.300) oder höher
- Monitor mit DDC/CI-Unterstützung

## Verfügbare Befehle

### Monitor-Informationen

#### get-info

Zeigt Informationen über alle angeschlossenen Monitore an.

```cmd
MonitorTools get-info
MonitorTools get-info --verbose
MonitorTools get-info -v
```

**Optionen:**
- `--verbose, -v`: Zeigt zusätzliche Informationen (z.B. Gerätenamen)

**Ausgabe:**
- Index (Monitor-Nummer, 0-basiert; jeder physische Monitor hat einen eigenen Index, auch im Klon-Modus, wie im PowerShell-Modul)
- Name (Beschreibung)
- Model (Modellname)
- SerialNumber (Seriennummer)
- Manufacturer (Hersteller)
- Firmware (Firmware-Version, falls verfügbar)
- WeekOfManufacture (Produktionswoche)
- YearOfManufacture (Produktionsjahr)

### Helligkeit

#### get-brightness

Zeigt die aktuelle Helligkeitsstufe eines Monitors an.

```cmd
MonitorTools get-brightness
MonitorTools get-brightness --monitor 0
MonitorTools get-brightness -m 1
```

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

#### set-brightness

Setzt die Helligkeitsstufe eines Monitors.

```cmd
MonitorTools set-brightness 50
MonitorTools set-brightness 75 --monitor 0
MonitorTools set-brightness 100 -m 1
```

**Argumente:**
- `<brightness>`: Helligkeitswert (0 bis zum vom Monitor gemeldeten Maximum, meist 100)

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)


### Kontrast

#### get-contrast

Zeigt die aktuelle Kontraststufe eines Monitors an.

```cmd
MonitorTools get-contrast
MonitorTools get-contrast -m 0
```

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

#### set-contrast

Setzt die Kontraststufe eines Monitors.

```cmd
MonitorTools set-contrast 50
MonitorTools set-contrast 75 -m 0
```

**Argumente:**
- `<contrast>`: Kontrastwert (0 bis zum vom Monitor gemeldeten Maximum, meist 100)

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

### Audio / Lautstärke

#### get-volume

Zeigt die aktuelle Lautstärke eines Monitors an.

```cmd
MonitorTools get-volume
MonitorTools get-volume -m 0
```

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

**Hinweis:** Funktioniert nur bei Monitoren mit integrierten Lautsprechern und DDC/CI-Unterstützung für Audio-Steuerung.

#### set-volume

Setzt die Lautstärke eines Monitors.

```cmd
MonitorTools set-volume 50
MonitorTools set-volume 75 -m 0
```

**Argumente:**
- `<volume>`: Lautstärkewert (0 bis zum vom Monitor gemeldeten Maximum, meist 100)

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

#### audio

Steuert die Stummschaltung eines Monitors.

```cmd
# Status abfragen
MonitorTools audio status
MonitorTools audio status -m 0

# Stummschalten
MonitorTools audio mute
MonitorTools audio mute -m 0

# Stummschaltung aufheben
MonitorTools audio unmute
MonitorTools audio unmute -m 0
```

**Unterbefehle:**
- `status`: Zeigt den aktuellen Stummschaltungsstatus
- `mute`: Schaltet den Monitor stumm
- `unmute`: Hebt die Stummschaltung auf

**Hinweis zur Kodierung (VCP 0x8D):** Die Werte sind gerätespezifisch und am Dell U4924DW geprüft: `0x00` = stumm, `0x01` = Ton an. Der Dell ignoriert die Werte des MCCS-Standards (`0x01` = stumm, `0x02` = Ton an). Auf einem MCCS-konformen Monitor würde `unmute` (schreibt `0x01`) daher stumm schalten. Für solche Monitore `vcp set 0x8D 1` (stumm) bzw. `vcp set 0x8D 2` (Ton an) verwenden.

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

### Eingabequellen

#### input

Verwaltet die Eingabequelle(n) des Monitors.

```cmd
# Aktuelle Eingabequelle abfragen
MonitorTools input get
MonitorTools input get -m 0

# Eingabequelle setzen
MonitorTools input set Hdmi1
MonitorTools input set Hdmi2 -m 0
MonitorTools input set DisplayPort
MonitorTools input set UsbC

# Linken und/oder rechten Eingang (PBP) umschalten
MonitorTools input switch --left Hdmi1
MonitorTools input switch --right UsbC
MonitorTools input switch --left UsbC --right Hdmi1 -m 0
```

**Unterbefehle:**
- `get`: Zeigt die aktuelle Eingabequelle
- `set <source>`: Setzt die Eingabequelle
- `switch [--left <source>] [--right <source>]`: Setzt den linken und/oder rechten Eingang. Bei aktivem PBP wird die Reihenfolge automatisch so gewählt, dass links und rechts nie gleichzeitig denselben Eingang verwenden (z. B. beim Tauschen der Seiten). Links und rechts dürfen bei aktivem PBP nicht gleich sein.

**Verfügbare Eingabequellen:**
- `Hdmi1` (0x11)
- `Hdmi2` (0x12)
- `DisplayPort` (0x0F)
- `UsbC` (0x1B)

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

**Hinweis:** Die verfügbaren Eingabequellen hängen vom Monitor-Modell ab. Nicht alle Monitore unterstützen alle aufgeführten Quellen.

### PBP (Picture-by-Picture)

PBP ermöglicht die gleichzeitige Anzeige von zwei Eingabequellen auf einem Monitor.

```cmd
# PBP-Status abfragen
MonitorTools pbp status
MonitorTools pbp status -m 0

# PBP aktivieren
MonitorTools pbp enable
MonitorTools pbp enable -m 0

# PBP deaktivieren
MonitorTools pbp disable
MonitorTools pbp disable -m 0

# Linke Eingabequelle für PBP setzen
MonitorTools pbp set-left Hdmi1
MonitorTools pbp set-left DisplayPort -m 0

# Rechte Eingabequelle für PBP setzen
MonitorTools pbp set-right Hdmi2
MonitorTools pbp set-right UsbC -m 0
```

**Unterbefehle:**
- `status`: Zeigt den PBP-Status und die rechte Eingabequelle
- `enable`: Aktiviert PBP-Modus
- `disable`: Deaktiviert PBP-Modus
- `set-left <input>`: Setzt die linke Eingabequelle für PBP
- `set-right <input>`: Setzt die rechte Eingabequelle für PBP

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)

**Hinweis:** PBP ist eine herstellerspezifische Funktion. Nicht alle Monitore unterstützen PBP. Der `set-left` Befehl ist ein Alias für `input set` und steuert VCP Code 0x60 (primärer Eingang).

### VCP (Low-Level DDC/CI-Steuerung)

Direkter Zugriff auf VCP-Feature-Codes für erweiterte Steuerung.

```cmd
# VCP-Feature-Wert lesen
MonitorTools vcp get 0x10
MonitorTools vcp get 10 -m 0
MonitorTools vcp get 0xE9

# VCP-Feature-Wert setzen
MonitorTools vcp set 0x10 75
MonitorTools vcp set 0xE9 0x24 -m 0
```

**Unterbefehle:**
- `get <code>`: Liest den aktuellen und maximalen Wert eines VCP-Codes
- `set <code> <value>`: Setzt einen VCP-Code auf einen bestimmten Wert

**Argumente:**
- `<code>`: VCP-Code in Hexadezimal (z.B. 0x10) oder Dezimal (z.B. 10)
- `<value>`: Zu setzender Wert (uint32)

**Optionen:**
- `--monitor, -m <index>`: Monitor-Index (0-basiert, Standard: 0)
- `--force, -f`: Erforderlich für kritische Codes (siehe unten)

**Kritische VCP-Codes:** Die folgenden Codes setzen Einstellungen zurück oder ändern den Energiezustand des Monitors. `vcp set` schreibt sie nur mit `--force`:

| Code | Bedeutung |
|------|-----------|
| `0x04` | Werkseinstellungen wiederherstellen |
| `0x05` | Helligkeit/Kontrast zurücksetzen |
| `0x06` | Geometrie zurücksetzen |
| `0x08` | Farbeinstellungen zurücksetzen |
| `0x0A` | TV-Einstellungen zurücksetzen |
| `0xB0` | Einstellungen speichern/wiederherstellen |
| `0xD6` | Energiemodus (kann den Monitor ausschalten) |

```cmd
MonitorTools vcp set 0xD6 1 --force
```

**Häufige VCP-Codes:**
- `0x10`: Helligkeit
- `0x12`: Kontrast
- `0x60`: Eingabequelle (Primary/Left)
- `0x62`: Audio-Lautstärke
- `0x8D`: Audio Mute (gerätespezifisch, Dell: 0x00 = Mute, 0x01 = Unmute; MCCS: 0x01 = Mute, 0x02 = Unmute)
- `0xC9`: Firmware-Version
- `0xE8`: PBP Right Input
- `0xE9`: PBP-Modus (0x00 = Aus, 0x24 = Ein)

**Warnung:** Falsche VCP-Werte können zu unerwartetem Verhalten führen. Verwenden Sie diesen Befehl nur, wenn Sie mit DDC/CI-Standards vertraut sind.

## Fehlerbehandlung

- Wenn kein Monitor gefunden wird, prüfen Sie, ob DDC/CI im Monitor-OSD aktiviert ist
- Manche Monitore unterstützen bestimmte Features nicht (z.B. Audio, PBP)
- Bei Fehlern wird eine Fehlermeldung auf stderr ausgegeben und das Programm beendet sich mit Exit-Code 1
