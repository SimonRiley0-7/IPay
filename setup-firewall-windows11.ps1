# PowerShell script optimized for Windows 11
# Creates permanent firewall rule for Node.js development
# Handles Windows 11 security features and execution policies

param(
    [switch]$Force
)

# Set execution policy for this session if needed
if ($Force -or $PSVersionTable.PSVersion.Major -ge 5) {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
}

Write-Host "🔧 Windows 11 Node.js Development Firewall Setup" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Windows 11 Instructions:" -ForegroundColor Yellow
    Write-Host "1. Right-click on Windows Terminal or PowerShell" -ForegroundColor White
    Write-Host "2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "3. Or use: Start Menu → Search 'PowerShell' → Right-click → 'Run as Administrator'" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
Write-Host "🖥️ Windows Version: $($osVersion.Major).$($osVersion.Minor)" -ForegroundColor Cyan

# Remove existing rules to avoid conflicts
Write-Host "🧹 Cleaning up existing firewall rules..." -ForegroundColor Yellow
$existingRules = @(
    "Node.js Development Port 3000",
    "Node.js Server Port 3000",
    "Node.js Backend Port 3000"
)

foreach ($ruleName in $existingRules) {
    netsh advfirewall firewall delete rule name="$ruleName" 2>$null
    Write-Host "   Removed: $ruleName" -ForegroundColor Gray
}

# Create comprehensive firewall rules for Windows 11
Write-Host "🔨 Creating Windows 11 optimized firewall rules..." -ForegroundColor Yellow

# Inbound rule
$inboundResult = netsh advfirewall firewall add rule name="Node.js Development Port 3000" dir=in action=allow protocol=TCP localport=3000 profile=any enable=yes

# Outbound rule (for better compatibility)
$outboundResult = netsh advfirewall firewall add rule name="Node.js Development Port 3000 Outbound" dir=out action=allow protocol=TCP localport=3000 profile=any enable=yes

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firewall rules created successfully!" -ForegroundColor Green
    Write-Host "📱 Inbound rule: Allows mobile devices to connect" -ForegroundColor Green
    Write-Host "📤 Outbound rule: Ensures proper communication" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create firewall rules!" -ForegroundColor Red
    Write-Host "Error code: $LASTEXITCODE" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Verify rules were created
Write-Host "`n🔍 Verifying firewall rules..." -ForegroundColor Yellow
$inboundRule = netsh advfirewall firewall show rule name="Node.js Development Port 3000" | Select-String "Enabled"
$outboundRule = netsh advfirewall firewall show rule name="Node.js Development Port 3000 Outbound" | Select-String "Enabled"

if ($inboundRule -and $outboundRule) {
    Write-Host "✅ Both rules are active and enabled" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some rules may not be properly configured" -ForegroundColor Yellow
}

# Get current IP address
Write-Host "`n🌐 Network Information:" -ForegroundColor Yellow
try {
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi" | Where-Object {$_.IPAddress -like "192.168.*"}).IPAddress
    if ($ipAddress) {
        Write-Host "📱 Your mobile device should connect to: http://$ipAddress:3000" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Could not detect WiFi IP address" -ForegroundColor Yellow
        Write-Host "📱 Use: http://192.168.1.38:3000 (or check with 'ipconfig')" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠️ Could not detect network configuration" -ForegroundColor Yellow
}

Write-Host "`n🎉 Windows 11 Firewall Setup Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "✅ Firewall rules are permanent and will survive:" -ForegroundColor Green
Write-Host "   • System reboots" -ForegroundColor White
Write-Host "   • Windows updates" -ForegroundColor White
Write-Host "   • Network profile changes" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Yellow
Write-Host "1. Start your backend server: cd backend && npm run dev" -ForegroundColor White
Write-Host "2. Test connection from your mobile device" -ForegroundColor White
Write-Host "3. Use the 'Test Backend Connection' button in your Flutter app" -ForegroundColor White

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host

