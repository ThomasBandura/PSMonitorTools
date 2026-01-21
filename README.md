# PSMonitorTools

Windows-Monitorsteuerung über DDC/CI - verfügbar als PowerShell-Modul und C# CLI-Tool.

[![PowerShell CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/PowerShell%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![C# CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/C%23%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![License](https://img.shields.io/github/license/ThomasBandura/PSMonitorTools)](LICENSE)

## 📦 Verfügbare Implementierungen

### 🔷 PowerShell Module
PowerShell-Modul für Scripting und Automation.
- 📖 [PowerShell Dokumentation](./docs/PowerShell/Get-MonitorInfo.md)
- 💾 [Installation](./docs/PowerShell/Installation.md)
- 📝 [Beispiele](./docs/Examples/PowerShell-Examples.md)

### 🔶 C# CLI Tool
Standalone Kommandozeilentool und Library.
- 📖 [C# CLI Dokumentation](./docs/CSharp/CLI-Usage.md)
- 💾 [Installation](./docs/CSharp/Installation.md)
- 📝 [Beispiele](./docs/Examples/CSharp-Examples.md)

## Projektziele

Dieses Projekt bietet eine zuverlässige programmatische Schnittstelle zur Steuerung physischer Monitor-Einstellungen unter Windows. Durch die Bereitstellung von DDC/CI-Funktionen über benutzerfreundliche APIs werden folgende Automatisierungsszenarien ermöglicht:

- **Automatisierung:** Eingabequellen-Wechsel basierend auf Arbeitskontext (z.B. Software-KVM-Logik)
- **Komfort:** Programmatische Anpassung von Helligkeit und Kontrast (z.B. nach Tageszeit)
- **Effizienz:** Verwaltung von Picture-by-Picture (PBP) Modi ohne umständliche OSD-Menüs
- **Inventarisierung:** Abrufen von Hardware-Details (Seriennummern, Firmware) für Asset-Management

## Features

### PowerShell Module

#### Monitor-Informationen
- **Get-MonitorInfo**: Ruft detaillierte Informationen ab (Modell, Seriennummer, Firmware, Herstellungsdatum)

#### Eingabequellen
- **Get-MonitorInput**: Zeigt aktuelle Eingabequellen und PBP-Status
- **Switch-MonitorInput**: Wechselt Eingabequellen mit intelligenter Kollisionserkennung für PBP-Modi

#### PBP (Picture-by-Picture)
- **Get-MonitorPBP**: Zeigt PBP-Status
- **Enable-MonitorPBP / Disable-MonitorPBP**: Aktiviert/Deaktiviert PBP-Modus

#### Audio
- **Get-MonitorAudioVolume / Set-MonitorAudioVolume**: Steuert Lautstärke der Monitor-Lautsprecher
- **Get-MonitorAudio**: Zeigt Stummschaltungs-Status
- **Enable-MonitorAudio / Disable-MonitorAudio**: Hebt Stummschaltung auf/Schaltet stumm

#### Bildeinstellungen
- **Get-MonitorBrightness / Set-MonitorBrightness**: Steuert Helligkeit (0-100)
- **Get-MonitorContrast / Set-MonitorContrast**: Steuert Kontrast (0-100)

#### Erweiterte Funktionen
- **Find-MonitorVcpCodes**: Interaktives Tool zum Entdecken versteckter VCP-Codes
- **Tab-Vervollständigung**: Unterstützt Argument-Completion für Monitor-Namen
- **WhatIf/Confirm**: Alle Set-Cmdlets unterstützen `-WhatIf` und `-Confirm`

### C# Library & CLI

#### MonitorService (Core Library)
- Ruft Monitor-Informationen ab (Modell, Hersteller, Seriennummer, Firmware)
- Steuert Helligkeit, Kontrast, Lautstärke
- Verwaltet Eingabequellen und PBP-Modus
- Direkter VCP-Feature-Zugriff für erweiterte Steuerung
- Wiederverwendbare `MonitorTools.Core` Library für Integration in eigene C#-Projekte

#### CLI-Befehle
- `get-info`: Monitor-Informationen anzeigen
- `get-brightness / set-brightness`: Helligkeit abrufen/setzen
- `get-contrast / set-contrast`: Kontrast abrufen/setzen
- `get-volume / set-volume`: Lautstärke abrufen/setzen
- `audio [status|mute|unmute]`: Audio-Steuerung
- `input [get|set]`: Eingabequellen-Verwaltung
- `pbp [status|enable|disable|set-right]`: PBP-Steuerung
- `vcp [get|set]`: Low-Level VCP-Feature-Zugriff

## Schnellstart

### PowerShell

```powershell
# Modul importieren
Import-Module ./PowerShell/PSMonitorTools/PSMonitorTools.psd1

# Monitor-Informationen abrufen
Get-MonitorInfo

# Helligkeit setzen
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 75

# Eingabequelle wechseln
Switch-MonitorInput -MonitorName 'Dell' -InputLeft DisplayPort

# PBP aktivieren und beide Eingänge setzen
Enable-MonitorPBP -MonitorName 'Dell'
Switch-MonitorInput -MonitorName 'Dell' -InputLeft Hdmi1 -InputRight UsbC
```

### C# CLI

```cmd
# Bauen
dotnet build CSharp/MonitorTools.sln

# Monitor-Informationen
MonitorTools get-info

# Helligkeit setzen
MonitorTools set-brightness 75

# Eingabequelle wechseln
MonitorTools input set DisplayPort

# PBP aktivieren
MonitorTools pbp enable
MonitorTools pbp set-right UsbC
```

## Installation

Detaillierte Installationsanleitungen:
- **PowerShell**: [Installationsanleitung](./docs/PowerShell/Installation.md)
- **C# CLI**: [Installationsanleitung](./docs/CSharp/Installation.md)

## Verwendungsbeispiele

### PowerShell

#### Monitor-Informationen abrufen

```powershell
# Alle Monitore anzeigen
Get-MonitorInfo

# Spezifischen Monitor anzeigen
Get-MonitorInfo -MonitorName 'Dell'
```

**Ausgabe:**
```text
Index Name                Model   SerialNumber Manufacturer Firmware WeekOfManufacture YearOfManufacture
----- ----                -----   ------------ ------------ -------- ----------------- -----------------
    0 Dell U2723DE        U2723DE ABC123       DEL          105                     26              2023
```

#### Eingabequelle abrufen und wechseln

```powershell
# Aktuelle Eingabe(n) anzeigen
Get-MonitorInput -MonitorName 'Dell'
```

**Ausgabe (PBP aktiv):**
```text
Name         Model    PBP   InputLeft InputRight
----         -----    ---   --------- ----------
Dell U2723DE U2723DE  True  Hdmi1     UsbC
```

```powershell
# Auf DisplayPort wechseln
Switch-MonitorInput -MonitorName 'Dell' -InputLeft DisplayPort

# PBP: Links auf HDMI1, rechts auf USB-C
Switch-MonitorInput -MonitorName 'Dell' -InputLeft Hdmi1 -InputRight UsbC
```

**Unterstützte Eingabequellen:**
- `Hdmi1` (0x11)
- `Hdmi2` (0x12)
- `DisplayPort` (0x0F)
- `UsbC` (0x1B)

#### PBP (Picture-by-Picture) steuern

```powershell
# PBP-Status abfragen
Get-MonitorPBP -MonitorName 'Dell'

# PBP aktivieren
Enable-MonitorPBP -MonitorName 'Dell'

# PBP deaktivieren
Disable-MonitorPBP -MonitorName 'Dell'
```

#### Audio steuern

```powershell
# Lautstärke abrufen
Get-MonitorAudioVolume -MonitorName 'Dell'

# Lautstärke auf 50% setzen
Set-MonitorAudioVolume -MonitorName 'Dell' -Volume 50

# Stummschaltungs-Status
Get-MonitorAudio -MonitorName 'Dell'

# Stummschaltung aufheben
Enable-MonitorAudio -MonitorName 'Dell'

# Stummschalten
Disable-MonitorAudio -MonitorName 'Dell'
```

#### Helligkeit & Kontrast

```powershell
# Helligkeit abrufen
Get-MonitorBrightness -MonitorName 'Dell'

# Helligkeit auf 75% setzen
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 75

# Kontrast abrufen
Get-MonitorContrast -MonitorName 'Dell'

# Kontrast auf 60% setzen
Set-MonitorContrast -MonitorName 'Dell' -Contrast 60
```

#### VCP-Codes entdecken

Interaktives Tool zum Finden versteckter VCP-Codes:

```powershell
# Standard-Scan (0x60 + 0xE0-0xFF)
Find-MonitorVcpCodes -MonitorName 'Dell'

# Vollständiger Scan (0x00-0xFF)
Find-MonitorVcpCodes -MonitorName 'Dell' -FullScan
```

### C# CLI

#### Monitor-Informationen

```cmd
> MonitorTools get-info
Found 2 monitor(s):

Monitor 0:
  Name:              Dell U2723DE
  Model:             U2723DE
  SerialNumber:      ABC123
  Manufacturer:      DEL

Monitor 1:
  Name:              ASUS ProArt
  Model:             PA279CV
  Manufacturer:      ACI
```

#### Helligkeit

```cmd
# Helligkeit abrufen
> MonitorTools get-brightness
Monitor 0 brightness: 75

# Helligkeit setzen
> MonitorTools set-brightness 50
Monitor 0 brightness set to 50

# Für spezifischen Monitor
> MonitorTools set-brightness 75 --monitor 1
```

#### Eingabequelle

```cmd
# Aktuelle Eingabe anzeigen
> MonitorTools input get
Monitor 0 input: Hdmi1

# Auf DisplayPort wechseln
> MonitorTools input set DisplayPort
Monitor 0 input switched to DisplayPort
```

#### PBP

```cmd
# Status
> MonitorTools pbp status
PBP Mode: Disabled

# Aktivieren
> MonitorTools pbp enable
PBP mode enabled

# Rechte Eingabe setzen
> MonitorTools pbp set-right UsbC
PBP right input set to UsbC
```

#### VCP-Feature-Zugriff

```cmd
# VCP-Code lesen
> MonitorTools vcp get 0x10
Monitor 0 VCP 0x10:
  Current: 75
  Maximum: 100

# VCP-Code setzen
> MonitorTools vcp set 0x10 50
Monitor 0 VCP 0x10 set to 50
```

## Praktische Szenarien

### Software-KVM-Switching

```powershell
# Funktion für schnellen Wechsel zwischen PCs
function Switch-ToWorkPC {
    Switch-MonitorInput -MonitorName 'Dell' -InputLeft UsbC
}

function Switch-ToGamingPC {
    Switch-MonitorInput -MonitorName 'Dell' -InputLeft Hdmi1
}
```

### Dual-PC-Setup mit PBP

```powershell
# Beide PCs gleichzeitig anzeigen
Enable-MonitorPBP -MonitorName 'Dell'
Switch-MonitorInput -MonitorName 'Dell' -InputLeft UsbC -InputRight Hdmi2
```

### Helligkeit nach Tageszeit

```powershell
$hour = (Get-Date).Hour

if ($hour -ge 6 -and $hour -lt 9) {
    Set-MonitorBrightness -MonitorName 'Dell' -Brightness 40
} elseif ($hour -ge 9 -and $hour -lt 18) {
    Set-MonitorBrightness -MonitorName 'Dell' -Brightness 80
} else {
    Set-MonitorBrightness -MonitorName 'Dell' -Brightness 25
}
```

## Systemvoraussetzungen

- **Betriebssystem:** Windows 10/11 oder Windows Server 2016+
- **PowerShell:** 5.1 oder PowerShell 7+ (pwsh)
- **C# CLI:** .NET 6.0 oder höher
- **Monitor:** DDC/CI-Unterstützung erforderlich (im Monitor-OSD aktivieren)

## Projektstruktur

```
PowerShell/
├── PSMonitorTools/          # PowerShell-Modul
│   ├── PSMonitorTools.psd1  # Manifest
│   ├── PSMonitorTools.psm1  # Hauptmodul
│   └── PSMonitorToolsHelper.ps1  # C# Helper-Klassen
├── Tests/                   # Pester-Tests
└── Get-MonitorInfo.ps1      # Legacy-Wrapper

CSharp/
├── src/
│   ├── MonitorTools.Core/   # Kernbibliothek
│   └── MonitorTools.CLI/    # CLI-Tool
└── tests/                   # Unit & Integration Tests

docs/
├── PowerShell/              # PowerShell-Dokumentation
├── CSharp/                  # C#-Dokumentation
└── Examples/                # Beispiele
```

## Technische Details

### DDC/CI & VCP-Codes

Dieses Projekt nutzt DDC/CI (Display Data Channel Command Interface) für die Monitor-Kommunikation. Die wichtigsten verwendeten VCP-Codes:

| Code | Beschreibung          | Verwendung |
|------|-----------------------|------------|
| 0x10 | Brightness            | Helligkeit |
| 0x12 | Contrast              | Kontrast   |
| 0x60 | Input Source (Left)   | Primäre Eingabe |
| 0x62 | Audio Volume          | Lautstärke |
| 0x8D | Audio Mute            | Stummschaltung |
| 0xC9 | Firmware Version      | Firmware   |
| 0xE8 | PBP Right Input       | Rechte PBP-Eingabe |
| 0xE9 | PBP/PIP Mode          | PBP-Modus  |

### APIs

- **PowerShell:** Windows Low-Level Monitor Configuration Functions + WMI (root\wmi\WmiMonitorID)
- **C# Core:** P/Invoke zu dxva2.dll, user32.dll, gdi32.dll
- **CLI:** System.CommandLine für moderne CLI-Erfahrung

## Beitragen

Contributions sind willkommen! Bitte beachten Sie:
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

## Lizenz

Dieses Projekt ist unter der [MIT License](LICENSE) lizenziert.

## Danksagungen

- DDC/CI-Standard: [VESA MCCS](https://vesa.org/)
- Getestet mit: Dell U2723DE, Dell U4924DW

## Changelog

Siehe [CHANGELOG.md](CHANGELOG.md) für Details zu Änderungen in jeder Version.

