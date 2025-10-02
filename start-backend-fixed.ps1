# Fixed Backend Startup Script with Network Diagnostics
# This script ensures the backend starts correctly and provides network diagnostics

Write-Host "🚀 Starting iPay Backend Server with Network Diagnostics..." -ForegroundColor Green

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check if npm is available
try {
    $npmVersion = npm --version
    Write-Host "✅ npm version: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ npm not found. Please install npm first." -ForegroundColor Red
    exit 1
}

# Navigate to backend directory
Set-Location "backend"

# Check if package.json exists
if (-not (Test-Path "package.json")) {
    Write-Host "❌ package.json not found in backend directory" -ForegroundColor Red
    exit 1
}

# Install dependencies if node_modules doesn't exist
if (-not (Test-Path "node_modules")) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "⚠️  .env file not found. Creating from .env.example..." -ForegroundColor Yellow
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "✅ Created .env file from .env.example" -ForegroundColor Green
        Write-Host "⚠️  Please update .env with your actual values" -ForegroundColor Yellow
    } else {
        Write-Host "❌ .env.example not found. Please create .env file manually" -ForegroundColor Red
        exit 1
    }
}

# Get current IP address
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" }).IPAddress | Select-Object -First 1
if ($ipAddress) {
    Write-Host "🌐 Current IP Address: $ipAddress" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Could not detect IP address" -ForegroundColor Yellow
}

# Check if port 3000 is available
$portCheck = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if ($portCheck) {
    Write-Host "⚠️  Port 3000 is already in use. Trying to stop existing process..." -ForegroundColor Yellow
    $process = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*server*" -or $_.ProcessName -eq "node" }
    if ($process) {
        Stop-Process -Id $process.Id -Force
        Write-Host "✅ Stopped existing Node.js process" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}

# Start the server
Write-Host "🚀 Starting backend server..." -ForegroundColor Green
Write-Host "📡 Server will be available at:" -ForegroundColor Cyan
Write-Host "   • http://localhost:3000" -ForegroundColor White
Write-Host "   • http://$ipAddress:3000" -ForegroundColor White
Write-Host "   • http://10.0.2.2:3000 (Android Emulator)" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Network Configuration for Flutter App:" -ForegroundColor Cyan
Write-Host "   • Physical Device: http://$ipAddress:3000" -ForegroundColor White
Write-Host "   • Android Emulator: http://10.0.2.2:3000" -ForegroundColor White
Write-Host "   • iOS Simulator: http://localhost:3000" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray

# Start the server
node server.js


