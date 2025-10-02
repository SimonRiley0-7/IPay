# PowerShell script to create permanent firewall rule for Node.js development
# Optimized for Windows 11
# Run this script as Administrator

Write-Host "🔧 Setting up permanent firewall rule for Node.js development on Windows 11..." -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click on PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "Or use Windows Terminal as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Remove existing rule if it exists (to avoid duplicates)
Write-Host "🧹 Cleaning up existing rules..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="Node.js Development Port 3000" 2>$null

# Create permanent firewall rule for Windows 11
Write-Host "🔨 Creating permanent firewall rule for Windows 11..." -ForegroundColor Yellow
$result = netsh advfirewall firewall add rule name="Node.js Development Port 3000" dir=in action=allow protocol=TCP localport=3000 profile=any enable=yes

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firewall rule created successfully!" -ForegroundColor Green
    Write-Host "📱 Your mobile device can now connect to your backend server" -ForegroundColor Green
    Write-Host "🌐 Backend accessible at: http://192.168.1.38:3000" -ForegroundColor Cyan
} else {
    Write-Host "❌ Failed to create firewall rule!" -ForegroundColor Red
    Write-Host "Error: $result" -ForegroundColor Red
}

# Verify the rule was created
Write-Host "`n🔍 Verifying firewall rule..." -ForegroundColor Yellow
netsh advfirewall firewall show rule name="Node.js Development Port 3000"

Write-Host "`n🎉 Setup complete! Your mobile device should now be able to connect." -ForegroundColor Green
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
