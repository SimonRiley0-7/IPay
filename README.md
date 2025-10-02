# iPay Backend API

Node.js + Express backend server for the iPay smart shopping application.

## Features

- 🔐 JWT-based authentication
- 🛒 Cart management APIs
- 📦 Product management
- 💳 Razorpay payment integration
- 🧾 Order management and digital receipts
- 🔒 Secure password hashing with bcrypt

## Project Structure

```
backend/
├── config/             # Database and other configurations
├── controllers/        # Route controllers
├── middleware/         # Custom middleware functions
├── models/            # MongoDB schemas and models
├── routes/            # API route definitions
├── utils/             # Utility functions
├── tests/             # Test files
├── server.js          # Main server file
├── package.json       # Dependencies and scripts
└── README.md          # This file
```

## Installation

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up environment variables:
   ```bash
   cp env.example .env
   ```
   Edit `.env` with your actual configuration values.

4. Start the development server:
   ```bash
   npm run dev
   ```

## Environment Variables

Copy `env.example` to `.env` and configure:

- `MONGODB_URI`: MongoDB Atlas connection string
- `JWT_SECRET`: Secret key for JWT token signing
- `RAZORPAY_KEY_ID` & `RAZORPAY_KEY_SECRET`: Razorpay API credentials
- `PORT`: Server port (default: 3000)

## API Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/google` - Google OAuth login
- `POST /api/auth/phone` - Phone OTP verification

### Products
- `GET /api/products/:barcode` - Get product by barcode
- `POST /api/products` - Add new product (admin)

### Cart
- `POST /api/cart/create` - Create new cart
- `POST /api/cart/addItem` - Add item to cart
- `POST /api/cart/removeItem` - Remove item from cart
- `GET /api/cart/:id` - Get cart details

### Orders
- `POST /api/orders/checkout` - Initiate Razorpay order
- `POST /api/orders/verify` - Verify payment
- `GET /api/orders/:userId` - Get user's order history

## Database Schema

See the main README for detailed MongoDB collection schemas.

## Development

```bash
# Install dependencies
npm install

# Run in development mode (with nodemon)
npm run dev

# Run in production mode
npm start

# Run tests
npm test
```

## Deployment

The backend is designed to be deployed on cloud platforms like:
- Render
- Heroku
- Railway
- DigitalOcean App Platform

Ensure environment variables are properly configured in your deployment platform.

