# PSMonitorTools

Windows-Monitorsteuerung über DDC/CI - verfügbar als PowerShell-Modul und C# CLI-Tool.

[![PowerShell CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/PowerShell%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![C# CI](https://github.com/ThomasBandura/PSMonitorTools/workflows/C%23%20CI/badge.svg)](https://github.com/ThomasBandura/PSMonitorTools/actions)
[![License](https://img.shields.io/github/license/ThomasBandura/PSMonitorTools)](LICENSE)

## License

This repository is licensed under the MIT License. See the LICENSE file for details.

## 📦 Verfügbare Implementierungen

### 🔷 PowerShell Module
PowerShell-Modul für Scripting und Automation.
- 📖 [PowerShell Dokumentation](./docs/PowerShell/Get-MonitorInfo.md)
- 💾 [Installation](./docs/PowerShell/Installation.md)

### 🔶 C# CLI Tool
Standalone Kommandozeilentool und Library.
- 📖 [C# CLI Dokumentation](./docs/CSharp/CLI-Usage.md)
- 💾 [Installation](./docs/CSharp/Installation.md)

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

