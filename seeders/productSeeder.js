const mongoose = require('mongoose');
const Product = require('../models/Product');
require('dotenv').config();

// Real Indian products with their actual barcodes
const products = [
  // Maggi Products
  {
    name: 'Maggi 2-Minute Noodles Masala',
    barcode: '8901030611234',
    price: 14.00,
    category: 'Instant Food',
    brand: 'Maggi',
    description: 'Instant noodles with masala flavor - 70g pack',
    image: 'https://via.placeholder.com/150x150?text=Maggi+Masala',
    stock: 50,
    weight: '70g',
    tags: ['instant', 'noodles', 'masala', 'vegetarian'],
    nutritionalInfo: {
      calories: 350,
      protein: 8,
      carbs: 60,
      fat: 12,
      fiber: 2
    }
  },
  {
    name: 'Maggi 2-Minute Noodles Chicken',
    barcode: '8901030611241',
    price: 14.00,
    category: 'Instant Food',
    brand: 'Maggi',
    description: 'Instant noodles with chicken flavor - 70g pack',
    image: 'https://via.placeholder.com/150x150?text=Maggi+Chicken',
    stock: 30,
    weight: '70g',
    tags: ['instant', 'noodles', 'chicken', 'non-vegetarian'],
    nutritionalInfo: {
      calories: 360,
      protein: 9,
      carbs: 58,
      fat: 13,
      fiber: 2
    }
  },

  // Britannia Products
  {
    name: 'Britannia Good Day Cookies',
    barcode: '8901030823456',
    price: 20.00,
    category: 'Biscuits',
    brand: 'Britannia',
    description: 'Butter cookies with cashew and almonds - 100g pack',
    image: 'https://via.placeholder.com/150x150?text=Good+Day',
    stock: 40,
    weight: '100g',
    tags: ['biscuits', 'cookies', 'butter', 'cashew', 'almonds'],
    nutritionalInfo: {
      calories: 500,
      protein: 6,
      carbs: 65,
      fat: 25,
      fiber: 2
    }
  },
  {
    name: 'Britannia Marie Gold Biscuits',
    barcode: '8901030823463',
    price: 15.00,
    category: 'Biscuits',
    brand: 'Britannia',
    description: 'Light and crispy Marie biscuits - 150g pack',
    image: 'https://via.placeholder.com/150x150?text=Marie+Gold',
    stock: 60,
    weight: '150g',
    tags: ['biscuits', 'marie', 'light', 'crispy'],
    nutritionalInfo: {
      calories: 420,
      protein: 8,
      carbs: 75,
      fat: 12,
      fiber: 3
    }
  },

  // Parle Products
  {
    name: 'Parle-G Glucose Biscuits',
    barcode: '8901030934567',
    price: 10.00,
    category: 'Biscuits',
    brand: 'Parle',
    description: 'Classic glucose biscuits - 100g pack',
    image: 'https://via.placeholder.com/150x150?text=Parle-G',
    stock: 100,
    weight: '100g',
    tags: ['biscuits', 'glucose', 'classic', 'energy'],
    nutritionalInfo: {
      calories: 450,
      protein: 7,
      carbs: 80,
      fat: 15,
      fiber: 1
    }
  },
  {
    name: 'Parle Monaco Salted Biscuits',
    barcode: '8901030934574',
    price: 12.00,
    category: 'Biscuits',
    brand: 'Parle',
    description: 'Salted square biscuits - 100g pack',
    image: 'https://via.placeholder.com/150x150?text=Monaco',
    stock: 80,
    weight: '100g',
    tags: ['biscuits', 'salted', 'square', 'crispy'],
    nutritionalInfo: {
      calories: 480,
      protein: 6,
      carbs: 70,
      fat: 20,
      fiber: 2
    }
  },

  // Coca-Cola Products
  {
    name: 'Coca-Cola Soft Drink',
    barcode: '8901030845678',
    price: 25.00,
    category: 'Beverages',
    brand: 'Coca-Cola',
    description: 'Classic Coca-Cola soft drink - 300ml bottle',
    image: 'https://via.placeholder.com/150x150?text=Coca-Cola',
    stock: 75,
    weight: '300ml',
    tags: ['soft drink', 'cola', 'carbonated', 'refreshing'],
    nutritionalInfo: {
      calories: 130,
      protein: 0,
      carbs: 33,
      fat: 0,
      fiber: 0
    }
  },
  {
    name: 'Sprite Lemon Lime Soft Drink',
    barcode: '8901030845685',
    price: 25.00,
    category: 'Beverages',
    brand: 'Coca-Cola',
    description: 'Lemon lime flavored soft drink - 300ml bottle',
    image: 'https://via.placeholder.com/150x150?text=Sprite',
    stock: 60,
    weight: '300ml',
    tags: ['soft drink', 'lemon', 'lime', 'carbonated', 'clear'],
    nutritionalInfo: {
      calories: 125,
      protein: 0,
      carbs: 32,
      fat: 0,
      fiber: 0
    }
  },

  // Amul Products
  {
    name: 'Amul Milk Chocolate',
    barcode: '8901030956789',
    price: 30.00,
    category: 'Chocolates',
    brand: 'Amul',
    description: 'Creamy milk chocolate bar - 40g',
    image: 'https://via.placeholder.com/150x150?text=Amul+Chocolate',
    stock: 45,
    weight: '40g',
    tags: ['chocolate', 'milk', 'creamy', 'sweet'],
    nutritionalInfo: {
      calories: 220,
      protein: 4,
      carbs: 25,
      fat: 12,
      fiber: 1
    }
  },
  {
    name: 'Amul Butter',
    barcode: '8901030956796',
    price: 45.00,
    category: 'Dairy',
    brand: 'Amul',
    description: 'Pure butter - 100g pack',
    image: 'https://via.placeholder.com/150x150?text=Amul+Butter',
    stock: 25,
    weight: '100g',
    tags: ['butter', 'dairy', 'pure', 'cooking'],
    nutritionalInfo: {
      calories: 720,
      protein: 1,
      carbs: 0,
      fat: 81,
      fiber: 0
    }
  },

  // Cadbury Products
  {
    name: 'Cadbury Dairy Milk Chocolate',
    barcode: '8901031067890',
    price: 35.00,
    category: 'Chocolates',
    brand: 'Cadbury',
    description: 'Classic dairy milk chocolate - 38g',
    image: 'https://via.placeholder.com/150x150?text=Dairy+Milk',
    stock: 55,
    weight: '38g',
    tags: ['chocolate', 'dairy milk', 'classic', 'smooth'],
    nutritionalInfo: {
      calories: 200,
      protein: 3,
      carbs: 22,
      fat: 12,
      fiber: 1
    }
  },
  {
    name: 'Cadbury 5 Star Chocolate',
    barcode: '8901031067897',
    price: 20.00,
    category: 'Chocolates',
    brand: 'Cadbury',
    description: '5 Star chocolate bar with caramel and nougat - 30g',
    image: 'https://via.placeholder.com/150x150?text=5+Star',
    stock: 40,
    weight: '30g',
    tags: ['chocolate', 'caramel', 'nougat', 'chewy'],
    nutritionalInfo: {
      calories: 150,
      protein: 2,
      carbs: 18,
      fat: 8,
      fiber: 1
    }
  },

  // Lays Products
  {
    name: 'Lays Classic Salted Chips',
    barcode: '8901031178901',
    price: 20.00,
    category: 'Snacks',
    brand: 'Lays',
    description: 'Classic salted potato chips - 52g pack',
    image: 'https://via.placeholder.com/150x150?text=Lays+Classic',
    stock: 70,
    weight: '52g',
    tags: ['chips', 'potato', 'salted', 'crispy'],
    nutritionalInfo: {
      calories: 280,
      protein: 3,
      carbs: 30,
      fat: 16,
      fiber: 2
    }
  },
  {
    name: 'Lays Magic Masala Chips',
    barcode: '8901031178908',
    price: 20.00,
    category: 'Snacks',
    brand: 'Lays',
    description: 'Magic masala flavored potato chips - 52g pack',
    image: 'https://via.placeholder.com/150x150?text=Lays+Masala',
    stock: 65,
    weight: '52g',
    tags: ['chips', 'potato', 'masala', 'spicy', 'flavored'],
    nutritionalInfo: {
      calories: 285,
      protein: 3,
      carbs: 31,
      fat: 16,
      fiber: 2
    }
  },

  // Kurkure Products
  {
    name: 'Kurkure Masala Munch',
    barcode: '8901031289012',
    price: 15.00,
    category: 'Snacks',
    brand: 'Kurkure',
    description: 'Masala flavored corn snacks - 50g pack',
    image: 'https://via.placeholder.com/150x150?text=Kurkure+Masala',
    stock: 85,
    weight: '50g',
    tags: ['snacks', 'corn', 'masala', 'crunchy'],
    nutritionalInfo: {
      calories: 260,
      protein: 4,
      carbs: 35,
      fat: 12,
      fiber: 3
    }
  },
  {
    name: 'Kurkure Green Chutney',
    barcode: '8901031289019',
    price: 15.00,
    category: 'Snacks',
    brand: 'Kurkure',
    description: 'Green chutney flavored corn snacks - 50g pack',
    image: 'https://via.placeholder.com/150x150?text=Kurkure+Green',
    stock: 75,
    weight: '50g',
    tags: ['snacks', 'corn', 'chutney', 'green', 'tangy'],
    nutritionalInfo: {
      calories: 255,
      protein: 4,
      carbs: 34,
      fat: 11,
      fiber: 3
    }
  },

  // Pepsi Products
  {
    name: 'Pepsi Cola Soft Drink',
    barcode: '8901031390123',
    price: 25.00,
    category: 'Beverages',
    brand: 'Pepsi',
    description: 'Classic Pepsi cola soft drink - 300ml bottle',
    image: 'https://via.placeholder.com/150x150?text=Pepsi',
    stock: 50,
    weight: '300ml',
    tags: ['soft drink', 'cola', 'carbonated', 'pepsi'],
    nutritionalInfo: {
      calories: 135,
      protein: 0,
      carbs: 34,
      fat: 0,
      fiber: 0
    }
  },
  {
    name: 'Mountain Dew Soft Drink',
    barcode: '8901031390130',
    price: 25.00,
    category: 'Beverages',
    brand: 'Pepsi',
    description: 'Citrus flavored soft drink - 300ml bottle',
    image: 'https://via.placeholder.com/150x150?text=Mountain+Dew',
    stock: 45,
    weight: '300ml',
    tags: ['soft drink', 'citrus', 'carbonated', 'energizing'],
    nutritionalInfo: {
      calories: 140,
      protein: 0,
      carbs: 35,
      fat: 0,
      fiber: 0
    }
  }
];

async function seedProducts() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/neocart');
    console.log('✅ Connected to MongoDB');

    // Clear existing products
    await Product.deleteMany({});
    console.log('🗑️ Cleared existing products');

    // Insert new products
    const insertedProducts = await Product.insertMany(products);
    console.log(`✅ Successfully seeded ${insertedProducts.length} products`);

    // Display some sample products with their barcodes
    console.log('\n📱 Sample products for barcode scanning:');
    console.log('=====================================');
    insertedProducts.slice(0, 5).forEach(product => {
      console.log(`📦 ${product.name}`);
      console.log(`   Barcode: ${product.barcode}`);
      console.log(`   Price: ₹${product.price}`);
      console.log(`   Brand: ${product.brand}`);
      console.log('');
    });

    console.log('🎯 You can now test barcode scanning with these products!');
    console.log('📱 Use any barcode scanner app to generate QR codes for these barcodes');

  } catch (error) {
    console.error('❌ Error seeding products:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
  }
}

// Run the seeder
if (require.main === module) {
  seedProducts();
}

module.exports = { seedProducts, products };








