# Gemeinsame Verhaltensfälle

Das Projekt hat zwei Implementierungen: das PowerShell-Modul (`PowerShell/PSMonitorTools`, lesbarer Quellcode, läuft ab Windows PowerShell 5.1) und `MonitorTools.Core` mit der CLI (C#, .NET 10). Beide bleiben bewusst getrennt (#34).

Damit sie sich gleich verhalten, beschreibt [`monitor-behavior.json`](monitor-behavior.json) die gemeinsamen Regeln als Testfälle. Beide Testsuiten lesen diese Datei:

| Abschnitt | Regel | PowerShell | C# |
|---|---|---|---|
| `pbpActive` | Wann gilt PBP/PIP als aktiv (VCP 0xE9)? | `Test-PbpModeActive` | `PbpModeValue.IsActive` |
| `leftInputValue` | Welcher Wert wird für den linken Eingang (VCP 0x60) geschrieben? | `Get-LeftInputValue` | `PbpModeValue.GetLeftInputValue` |
| `continuousValue` | Grenze für Helligkeit, Kontrast, Lautstärke | `Get-VcpValueLimit` | `MonitorService.GetContinuousLimit` |
| `inputSwitch` | Reihenfolge und Ablehnung beim Umschalten mit PBP | `Get-InputSwitchPlan` | `InputSwitchPlanner.Evaluate` |

- Pester: [`PowerShell/Tests/Behavior.Spec.Tests.ps1`](../PowerShell/Tests/Behavior.Spec.Tests.ps1). Die Datei prüft die Regelfunktionen und zusätzlich `Switch-MonitorInput` mit einem simulierten Monitor. Sie läuft in der CI unter PowerShell 7 und Windows PowerShell 5.1.
- xUnit: [`CSharp/tests/MonitorTools.Core.Tests/BehaviorSpecTests.cs`](../CSharp/tests/MonitorTools.Core.Tests/BehaviorSpecTests.cs)

## Eine Regel ändern

1. Den Fall in `monitor-behavior.json` ergänzen oder anpassen.
2. Beide Implementierungen anpassen. Änderungen an `spec/**` starten beide CI-Workflows, eine Seite allein schlägt dann fehl.

## Format

- Hex-Werte sind Strings mit `0x`-Präfix (`"0xF0F"`), Eingänge die Namen aus `MonitorInput` (`Hdmi1`, `Hdmi2`, `DisplayPort`, `UsbC`).
- `inputSwitch`: `steps` ist die erwartete Reihenfolge (`"Right:Hdmi1"`), `error` ist `null`, `"Conflict"` (links und rechts gleich) oder `"Swap"` (Seiten tauschen). `currentLeft`/`currentRight` sind `null`, wenn sie unbekannt sind (PBP aus oder nicht lesbar).
- `note` ist ein freier Kommentar und wird nicht ausgewertet.
