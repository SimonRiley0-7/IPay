# 🪟 Windows 11 Development Setup Guide

## 🎯 Quick Start (3 Steps)

### Step 1: Setup Firewall (One-time)
```powershell
# Right-click PowerShell → "Run as Administrator"
.\setup-firewall-windows11.ps1
```

### Step 2: Start Backend Server
```powershell
# In regular PowerShell (no admin needed)
.\start-backend.ps1
```

### Step 3: Test Connection
- Use the "Test Backend Connection" button in your Flutter app
- Should show: "✅ Backend connection successful!"

## 🔧 Windows 11 Specific Features

### Enhanced Security
- Windows 11 has stricter firewall rules by default
- The script creates both inbound and outbound rules for better compatibility
- Rules are marked as permanent and survive Windows updates

### PowerShell Improvements
- Better error handling and user feedback
- Automatic execution policy handling
- Enhanced network detection

## 🚀 Alternative Methods

### Method 1: Windows Terminal (Recommended)
1. Open **Windows Terminal** as Administrator
2. Navigate to your project: `cd E:\Shivam\NeoCart`
3. Run: `.\setup-firewall-windows11.ps1`

### Method 2: PowerShell ISE
1. Right-click **PowerShell ISE** → "Run as Administrator"
2. Open the script file
3. Press F5 to run

### Method 3: Manual GUI (Most Reliable)
1. Press `Windows + R` → Type `wf.msc` → Enter
2. Click "Inbound Rules" → "New Rule"
3. Select "Port" → "TCP" → "Specific local ports" → Enter `3000`
4. Select "Allow the connection"
5. Check all profiles (Domain, Private, Public)
6. Name: "Node.js Development Port 3000"

## 🔍 Troubleshooting Windows 11

### If Scripts Don't Run
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### If Firewall Rules Don't Persist
- Windows 11 may reset rules during major updates
- Re-run the setup script after Windows updates
- Consider using the manual GUI method for maximum reliability

### If IP Address Changes
```powershell
# Run this to update all config files with new IP
.\update-ip-config.ps1
```

## 📱 Mobile Device Connection

### Requirements
- Both devices on same WiFi network
- Windows 11 firewall allows port 3000
- Backend server running on port 3000

### Testing Connection
1. From mobile device, try to access: `http://192.168.1.38:3000/api/auth/test`
2. Should return JSON response with success message
3. If not working, check firewall and network settings

## 🎉 Success Indicators

✅ **Firewall Setup Complete:**
- Script runs without errors
- Shows "Firewall rules created successfully"
- Both inbound and outbound rules are active

✅ **Backend Server Running:**
- Shows "🚀 iPay Backend Server running on port 3000"
- No error messages in console
- Accessible from browser at `http://localhost:3000`

✅ **Mobile Connection Working:**
- "Test Backend Connection" button shows success
- Google Sign-In works
- OTP sending works
- No "Connection refused" or "No route to host" errors

## 🔄 Maintenance

### After Windows Updates
- Re-run firewall setup if connection stops working
- Check if IP address changed with `ipconfig`
- Update config files if needed

### Regular Checks
- Verify backend server is running
- Test mobile connection periodically
- Keep firewall rules active

## 📞 Support

If you continue having issues:
1. Check Windows 11 version and updates
2. Verify network connectivity between devices
3. Try the manual GUI firewall setup method
4. Ensure no antivirus software is blocking connections

