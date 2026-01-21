# C# Library Examples

## Using MonitorTools.Core in Your Project

### Installation

Add reference to `MonitorTools.Core`:
```xml
<ItemGroup>
  <ProjectReference Include="path\to\MonitorTools.Core\MonitorTools.Core.csproj" />
</ItemGroup>
```

Or via NuGet (if published):
```bash
dotnet add package MonitorTools.Core
```

## Basic Usage

### Get all monitors
```csharp
using MonitorTools.Core;

var service = new MonitorService();
var monitors = service.GetMonitors();

foreach (var monitor in monitors)
{
    Console.WriteLine($"Monitor {monitor.Index}: {monitor}");
}
```

### Get brightness
```csharp
var service = new MonitorService();
int brightness = service.GetBrightness(monitorIndex: 0);
Console.WriteLine($"Current brightness: {brightness}%");
```

### Set brightness
```csharp
var service = new MonitorService();
service.SetBrightness(brightness: 75, monitorIndex: 0);
Console.WriteLine("Brightness updated!");
```

## Advanced Examples

### Monitor information display
```csharp
using MonitorTools.Core;

public class MonitorDisplay
{
    private readonly IMonitorService _monitorService;

    public MonitorDisplay(IMonitorService monitorService)
    {
        _monitorService = monitorService;
    }

    public void DisplayAllMonitors()
    {
        var monitors = _monitorService.GetMonitors();

        Console.WriteLine($"Found {monitors.Length} monitor(s):\n");

        foreach (var monitor in monitors)
        {
            Console.WriteLine($"Monitor {monitor.Index}:");
            Console.WriteLine($"  Device:     {monitor.DeviceName}");
            Console.WriteLine($"  Model:      {monitor.Model}");
            Console.WriteLine($"  Resolution: {monitor.Width}x{monitor.Height}");
            Console.WriteLine($"  Primary:    {monitor.IsPrimary}");
            
            if (monitor.Brightness.HasValue)
            {
                Console.WriteLine($"  Brightness: {monitor.Brightness}%");
            }
            Console.WriteLine();
        }
    }
}
```

### Brightness scheduler
```csharp
using MonitorTools.Core;

public class BrightnessScheduler
{
    private readonly IMonitorService _monitorService;
    private readonly Timer _timer;

    public BrightnessScheduler(IMonitorService monitorService)
    {
        _monitorService = monitorService;
        _timer = new Timer(CheckAndAdjustBrightness, null, TimeSpan.Zero, TimeSpan.FromMinutes(30));
    }

    private void CheckAndAdjustBrightness(object? state)
    {
        var hour = DateTime.Now.Hour;
        
        int targetBrightness = hour switch
        {
            >= 6 and < 9 => 60,    // Morning
            >= 9 and < 17 => 100,   // Day
            >= 17 and < 21 => 70,   // Evening
            _ => 30                 // Night
        };

        var monitors = _monitorService.GetMonitors();
        for (int i = 0; i < monitors.Length; i++)
        {
            try
            {
                _monitorService.SetBrightness(targetBrightness, i);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to adjust monitor {i}: {ex.Message}");
            }
        }
    }
}
```

### Dependency injection
```csharp
using Microsoft.Extensions.DependencyInjection;
using MonitorTools.Core;
using MonitorTools.Core.Interfaces;

public class Program
{
    public static void Main(string[] args)
    {
        var services = new ServiceCollection();
        services.AddSingleton<IMonitorService, MonitorService>();
        
        var serviceProvider = services.BuildServiceProvider();
        var monitorService = serviceProvider.GetRequiredService<IMonitorService>();
        
        var monitors = monitorService.GetMonitors();
        Console.WriteLine($"Found {monitors.Length} monitors");
    }
}
```

### WPF integration
```csharp
using System.Windows;
using MonitorTools.Core;

public partial class MainWindow : Window
{
    private readonly MonitorService _monitorService;

    public MainWindow()
    {
        InitializeComponent();
        _monitorService = new MonitorService();
        LoadMonitors();
    }

    private void LoadMonitors()
    {
        var monitors = _monitorService.GetMonitors();
        MonitorListBox.ItemsSource = monitors;
    }

    private void BrightnessSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (MonitorListBox.SelectedIndex >= 0)
        {
            try
            {
                _monitorService.SetBrightness(
                    (int)e.NewValue, 
                    MonitorListBox.SelectedIndex);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
```
