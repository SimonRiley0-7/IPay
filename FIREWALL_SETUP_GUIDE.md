# 🔥 Permanent Firewall Setup Guide

## Why This Keeps Happening
Windows Firewall rules can be temporary or get reset during:
- Windows Updates
- System restarts
- Security software updates
- Network profile changes

## 🎯 PERMANENT SOLUTION: Manual GUI Setup

### Step 1: Open Windows Defender Firewall
1. Press `Windows + R`
2. Type `wf.msc` and press Enter
3. Click "Yes" if prompted by UAC

### Step 2: Create Inbound Rule
1. Click **"Inbound Rules"** in the left panel
2. Click **"New Rule..."** in the right panel
3. Select **"Port"** → Click **Next**
4. Select **"TCP"** → Select **"Specific local ports"**
5. Enter **3000** → Click **Next**
6. Select **"Allow the connection"** → Click **Next**
7. Check **ALL THREE** boxes:
   - ☑️ Domain
   - ☑️ Private  
   - ☑️ Public
8. Click **Next**
9. Name: **"Node.js Development Port 3000"**
10. Description: **"Allows mobile devices to connect to Node.js backend server"**
11. Click **Finish**

### Step 3: Create Outbound Rule (Optional but Recommended)
1. Click **"Outbound Rules"** in the left panel
2. Repeat the same steps as above
3. Name: **"Node.js Development Port 3000 Outbound"**

## 🚀 Quick Setup Scripts

### Option A: PowerShell Script
```powershell
# Right-click PowerShell → "Run as Administrator"
.\setup-firewall.ps1
```

### Option B: Batch File
```cmd
# Right-click setup-firewall.bat → "Run as administrator"
setup-firewall.bat
```

## ✅ Verification
After setup, test the connection:
1. Start your backend server: `cd backend && npm run dev`
2. Use the "Test Backend Connection" button in your Flutter app
3. Should show: "✅ Backend connection successful!"

## 🔧 Troubleshooting
If it still doesn't work:
1. Check if your IP address changed: `ipconfig`
2. Update the IP in your Flutter config files
3. Restart your backend server
4. Try connecting from another device to test

## 📱 Mobile Device Requirements
- Both devices must be on the same WiFi network
- Mobile device should be able to ping your computer's IP
- No VPN or proxy interfering with local network traffic

