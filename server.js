const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const os = require('os');
const path = require('path');
require('dotenv').config();

// Import database connection
const connectDB = require('./config/database');

// Import route handlers
const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const walletRoutes = require('./routes/wallet');
const orderRoutes = require('./routes/orders');
// const uploadRoutes = require('./routes/upload');

const app = express();
const PORT = process.env.PORT || 3000;

// Function to get all local network IP addresses
function getLocalIPAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Skip internal (loopback) and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push(iface.address);
      }
    }
  }
  
  return addresses;
}

// Middleware
app.use(helmet()); // Security headers

// Serve static files from uploads directory
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Dynamic CORS configuration - Allow all local network IPs
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, postman)
    if (!origin) return callback(null, true);
    
    // Get all local IPs
    const localIPs = getLocalIPAddresses();
    
    // Build allowed origins dynamically
    const allowedOrigins = [
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000', // Android emulator
      ...localIPs.map(ip => `http://${ip}:3000`),
      ...localIPs.map(ip => `http://${ip}:${PORT}`)
    ];
    
    // Check if origin is in allowed list or is a local IP pattern
    const isLocalIP = /^http:\/\/(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}):\d+$/.test(origin);
    
    if (allowedOrigins.includes(origin) || isLocalIP) {
      callback(null, true);
    } else {
      callback(null, true); // For development, allow all. In production, restrict this.
    }
  },
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions)); // Enable CORS with dynamic IP support
app.use(morgan('combined')); // Logging
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies
app.use(express.static('public')); // Serve static files

// Connect to database
connectDB();

// Routes
app.get('/', (req, res) => {
  const localIPs = getLocalIPAddresses();
  res.json({
    message: 'iPay Backend API Server',
    version: '1.0.0',
    status: 'Running',
    networkInfo: {
      localIPs: localIPs,
      accessURLs: localIPs.map(ip => `http://${ip}:${PORT}`)
    },
    endpoints: {
      auth: '/api/auth',
      products: '/api/products',
      cart: '/api/cart',
      orders: '/api/orders'
    }
  });
});

// Network info endpoint for Flutter app to discover server
app.get('/api/network/info', (req, res) => {
  const localIPs = getLocalIPAddresses();
  res.json({
    success: true,
    port: PORT,
    ips: localIPs,
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/orders', orderRoutes);
// app.use('/api/upload', uploadRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : {}
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    message: 'Route not found'
  });
});

// Start server on all network interfaces
app.listen(PORT, '0.0.0.0', () => {
  const localIPs = getLocalIPAddresses();
  
  console.log('\n🚀 iPay Backend Server Started Successfully!\n');
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔌 Port: ${PORT}\n`);
  
  console.log('📱 Access your server from:');
  console.log(`   Local:    http://localhost:${PORT}`);
  console.log(`   Local:    http://127.0.0.1:${PORT}`);
  
  if (localIPs.length > 0) {
    console.log('\n🌐 Network URLs (for mobile devices):');
    localIPs.forEach(ip => {
      console.log(`   Network:  http://${ip}:${PORT}`);
    });
  } else {
    console.log('\n⚠️  No network interfaces found. Server only accessible locally.');
  }
  
  console.log('\n💡 Tips:');
  console.log('   - Make sure your phone and computer are on the same WiFi');
  console.log('   - Check firewall settings if connection fails');
  console.log('   - Visit http://[your-ip]:3000 in phone browser to test\n');
});

module.exports = app;