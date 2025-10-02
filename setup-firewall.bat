@echo off
echo 🔧 Setting up permanent firewall rule for Node.js development...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✅ Running as Administrator
) else (
    echo ❌ This script must be run as Administrator!
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

echo 🧹 Cleaning up existing rules...
netsh advfirewall firewall delete rule name="Node.js Development Port 3000" >nul 2>&1

echo 🔨 Creating permanent firewall rule...
netsh advfirewall firewall add rule name="Node.js Development Port 3000" dir=in action=allow protocol=TCP localport=3000 profile=any

if %errorLevel% == 0 (
    echo ✅ Firewall rule created successfully!
    echo 📱 Your mobile device can now connect to your backend server
    echo 🌐 Backend accessible at: http://192.168.1.38:3000
) else (
    echo ❌ Failed to create firewall rule!
)

echo.
echo 🔍 Verifying firewall rule...
netsh advfirewall firewall show rule name="Node.js Development Port 3000"

echo.
echo 🎉 Setup complete! Your mobile device should now be able to connect.
pause

