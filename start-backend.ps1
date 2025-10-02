# PowerShell script to start the backend server
# Windows 11 compatible

Write-Host "🚀 Starting iPay Backend Server..." -ForegroundColor Green

# Check if backend directory exists
if (-not (Test-Path "backend")) {
    Write-Host "❌ Backend directory not found!" -ForegroundColor Red
    Write-Host "Make sure you're running this from the project root directory." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Navigate to backend directory
Set-Location backend

# Check if package.json exists
if (-not (Test-Path "package.json")) {
    Write-Host "❌ package.json not found in backend directory!" -ForegroundColor Red
    Write-Host "Make sure you've installed the dependencies with 'npm install'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if node_modules exists
if (-not (Test-Path "node_modules")) {
    Write-Host "⚠️ node_modules not found. Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "✅ Dependencies are ready" -ForegroundColor Green
Write-Host "🌐 Starting server on port 3000..." -ForegroundColor Cyan
Write-Host "📱 Mobile devices can connect to: http://192.168.1.38:3000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Gray

# Start the development server
npm run dev

