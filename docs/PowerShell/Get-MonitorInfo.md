# PSMonitorTools PowerShell Module - Benutzerhandbuch

## Übersicht

PSMonitorTools ist ein PowerShell-Modul zur Steuerung von Monitoren über DDC/CI (Display Data Channel Command Interface). Es ermöglicht das Abfragen und Setzen von Monitor-Einstellungen wie Helligkeit, Kontrast, Lautstärke, Eingabequellen und PBP-Modus.

## Systemvoraussetzungen

- Windows 11
- PowerShell 5.1 oder höher
- Monitor mit DDC/CI-Unterstützung

## Installation

```powershell
# Modul importieren
Import-Module .\PSMonitorTools\PSMonitorTools.psd1
```

## Verfügbare Cmdlets

### Monitor-Informationen

#### Get-MonitorInfo

Zeigt Informationen über alle angeschlossenen Monitore an.

```powershell
Get-MonitorInfo
Get-MonitorInfo -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (optional): Filter nach Monitor-Name, Modell oder Hersteller

**Rückgabewerte:**
- `Index`: Monitor-Index (0-basiert)
- `Name`: Monitor-Beschreibung
- `Model`: Modellname
- `SerialNumber`: Seriennummer
- `Manufacturer`: Hersteller
- `Firmware`: Firmware-Version (falls verfügbar)
- `WeekOfManufacture`: Produktionswoche
- `YearOfManufacture`: Produktionsjahr

**Beispiele:**

```powershell
# Alle Monitore anzeigen
Get-MonitorInfo

# Nur Dell-Monitore anzeigen
Get-MonitorInfo -MonitorName 'Dell'

# Nach Modell filtern
Get-MonitorInfo -MonitorName 'U2723DE'
```

### Helligkeit

#### Get-MonitorBrightness

Zeigt die aktuelle Helligkeitsstufe eines Monitors an.

```powershell
Get-MonitorBrightness -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

**Rückgabewerte:**
- Objekt mit `Name`, `Model` und `Brightness`

#### Set-MonitorBrightness

Setzt die Helligkeitsstufe eines Monitors.

```powershell
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 50
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors
- `-Brightness` (erforderlich): Helligkeitswert (0-100)

**Beispiele:**

```powershell
# Helligkeit auf 75% setzen
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 75

# Mit WhatIf testen (keine Änderung)
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 50 -WhatIf

# Mit Bestätigung
Set-MonitorBrightness -MonitorName 'Dell' -Brightness 30 -Confirm
```

### Kontrast

#### Get-MonitorContrast

Zeigt die aktuelle Kontraststufe eines Monitors an.

```powershell
Get-MonitorContrast -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

#### Set-MonitorContrast

Setzt die Kontraststufe eines Monitors.

```powershell
Set-MonitorContrast -MonitorName 'Dell' -Contrast 75
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors
- `-Contrast` (erforderlich): Kontrastwert (0-100)

### Audio / Lautstärke

#### Get-MonitorAudioVolume

Zeigt die aktuelle Lautstärke eines Monitors an.

```powershell
Get-MonitorAudioVolume -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

**Hinweis:** Funktioniert nur bei Monitoren mit integrierten Lautsprechern.

#### Set-MonitorAudioVolume

Setzt die Lautstärke eines Monitors.

```powershell
Set-MonitorAudioVolume -MonitorName 'Dell' -Volume 50
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors
- `-Volume` (erforderlich): Lautstärkewert (0-100)

#### Get-MonitorAudio

Zeigt den Stummschaltungsstatus eines Monitors an.

```powershell
Get-MonitorAudio -MonitorName 'Dell'
```

**Rückgabewerte:**
- Objekt mit `Name`, `Model` und `AudioEnabled` ($true = unmuted, $false = muted)

#### Enable-MonitorAudio

Hebt die Stummschaltung auf (Unmute).

```powershell
Enable-MonitorAudio -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

#### Disable-MonitorAudio

Schaltet den Monitor stumm (Mute).

```powershell
Disable-MonitorAudio -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

### Eingabequellen

#### Get-MonitorInput

Zeigt die aktuelle(n) Eingabequelle(n) eines Monitors an.

```powershell
Get-MonitorInput -MonitorName 'Dell'
```

**Parameter:**
- `-MonitorName` (erforderlich): Name oder Modell des Monitors

**Rückgabewerte:**
- `Name`: Monitor-Beschreibung
- `Model`: Modellname
- `PBP`: PBP-Status ($true/$false)
- `InputLeft`: Linke/Primäre Eingabequelle
- `InputRight`: Rechte Eingabequelle (nur wenn PBP aktiv)

**Mögliche Eingabequellen:**
- `Hdmi1` (0x11)
- `Hdmi2` (0x12)
- `DisplayPort` (0x0F)
- `UsbC` (0x1B)
- `Unknown (0xXX)` bei unbekannten Werten

