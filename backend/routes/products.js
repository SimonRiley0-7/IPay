const express = require('express');
const Product = require('../models/Product');
const auth = require('../middleware/auth');
const router = express.Router();

// Get product by barcode
router.get('/barcode/:barcode', async (req, res) => {
  try {
    const { barcode } = req.params;
    
    console.log(`🔍 Looking up product with barcode: ${barcode}`);
    
    const product = await Product.findOne({ 
      barcode: barcode,
      isActive: true 
    });
    
    if (!product) {
      console.log(`❌ Product not found for barcode: ${barcode}`);
      return res.status(404).json({
        success: false,
        message: 'Product not found',
        barcode: barcode
      });
    }
    
    console.log(`✅ Product found: ${product.name} - ₹${product.price}`);
    
    res.json({
      success: true,
      product: {
        id: product._id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        category: product.category,
        brand: product.brand,
        description: product.description,
        image: product.image,
        stock: product.stock,
        weight: product.weight,
        tags: product.tags,
        nutritionalInfo: product.nutritionalInfo
      }
    });
    
  } catch (error) {
    console.error('❌ Error looking up product:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get all products (with pagination)
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    
    const products = await Product.find({ isActive: true })
      .skip(skip)
      .limit(limit)
      .sort({ createdAt: -1 });
    
    const total = await Product.countDocuments({ isActive: true });
    
    res.json({
      success: true,
      products: products.map(product => ({
        id: product._id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        category: product.category,
        brand: product.brand,
        description: product.description,
        image: product.image,
        stock: product.stock,
        weight: product.weight,
        tags: product.tags
      })),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
    
  } catch (error) {
    console.error('❌ Error fetching products:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Search products
router.get('/search', async (req, res) => {
  try {
    const { q, category, brand } = req.query;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    
    let query = { isActive: true };
    
    if (q) {
      query.$text = { $search: q };
    }
    
    if (category) {
      query.category = new RegExp(category, 'i');
    }
    
    if (brand) {
      query.brand = new RegExp(brand, 'i');
    }
    
    const products = await Product.find(query)
      .skip(skip)
      .limit(limit)
      .sort(q ? { score: { $meta: 'textScore' } } : { createdAt: -1 });
    
    const total = await Product.countDocuments(query);
    
    res.json({
      success: true,
      products: products.map(product => ({
        id: product._id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        category: product.category,
        brand: product.brand,
        description: product.description,
        image: product.image,
        stock: product.stock,
        weight: product.weight,
        tags: product.tags
      })),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
    
  } catch (error) {
    console.error('❌ Error searching products:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get product categories
router.get('/categories', async (req, res) => {
  try {
    const categories = await Product.distinct('category', { isActive: true });
    
    res.json({
      success: true,
      categories: categories.sort()
    });
    
  } catch (error) {
    console.error('❌ Error fetching categories:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get product brands
router.get('/brands', async (req, res) => {
  try {
    const brands = await Product.distinct('brand', { isActive: true });
    
    res.json({
      success: true,
      brands: brands.sort()
    });
    
  } catch (error) {
    console.error('❌ Error fetching brands:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

module.exports = router;








