# Allow phone on the same Wi-Fi to reach local Kabadiwala backend + AI.
# Right-click → Run with PowerShell AS ADMINISTRATOR.

$ErrorActionPreference = "Stop"

foreach ($port in @(5001, 8000)) {
  $name = "Kabadiwala Port $port"
  netsh advfirewall firewall delete rule name="$name" | Out-Null
  netsh advfirewall firewall add rule `
    name="$name" `
    dir=in `
    action=allow `
    protocol=TCP `
    localport=$port `
    profile=any | Out-Null
  Write-Host "Allowed inbound TCP $port ($name)"
}

Write-Host ""
Write-Host "Done. Phone can now reach:"
Write-Host "  Backend  http://<your-wifi-ip>:5001"
Write-Host "  AI       http://<your-wifi-ip>:8000  (optional; app uses backend gateway)"
Write-Host ""
Write-Host "Your current Wi-Fi IPv4:"
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN' -and $_.IPAddress -notlike '169.254.*' } |
  ForEach-Object { Write-Host "  $($_.IPAddress)" }
