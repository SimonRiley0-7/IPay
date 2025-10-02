# PowerShell script to automatically update IP configuration
# This script finds your current IP and updates the Flutter config files

Write-Host "🔍 Finding your current IP address..." -ForegroundColor Green

# Get the current IP address
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi" | Where-Object {$_.IPAddress -like "192.168.*"}).IPAddress

if (-not $ipAddress) {
    Write-Host "❌ Could not find WiFi IP address!" -ForegroundColor Red
    Write-Host "Make sure you're connected to WiFi and try again." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "✅ Found IP address: $ipAddress" -ForegroundColor Green

# Update the config files
$configFiles = @(
    "frontend/lib/config/api_config.dart",
    "frontend/lib/config/network_config.dart",
    "backend/server.js"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "📝 Updating $file..." -ForegroundColor Yellow
        
        # Read the file content
        $content = Get-Content $file -Raw
        
        # Replace the IP address pattern
        $content = $content -replace '192\.168\.\d+\.\d+', $ipAddress
        
        # Write back to file
        Set-Content $file -Value $content -NoNewline
        
        Write-Host "✅ Updated $file with IP: $ipAddress" -ForegroundColor Green
    } else {
        Write-Host "⚠️ File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host "`n🎉 IP configuration updated successfully!" -ForegroundColor Green
Write-Host "📱 Your mobile device should now connect to: http://$ipAddress:3000" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run the firewall setup script" -ForegroundColor White
Write-Host "2. Restart your backend server" -ForegroundColor White
Write-Host "3. Test the connection from your mobile device" -ForegroundColor White

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

