const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const router = express.Router();
const app = express();
const PORT = process.env.PORT || 5000;
const chatSessions = new Map();
// Middleware
app.use(cors({
  origin: 'http://localhost:5173', // your frontend URL
  credentials: true
}));
app.use(express.json());

// MongoDB Connection
mongoose.connect('mongodb://localhost:27017/register', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('MongoDB connected successfully'))
.catch((err) => console.error('MongoDB connection error:', err));
// Add Chat Message Schema
const chatMessageSchema = new mongoose.Schema({
  sessionId: { type: String, required: true },
  messages: [{
    role: { type: String, enum: ['user', 'bot'], required: true },
    content: { type: String, required: true },
    timestamp: { type: Date, default: Date.now }
  }],
  createdAt: { type: Date, default: Date.now },
  lastUpdated: { type: Date, default: Date.now }
});

const ChatMessage = mongoose.model('ChatMessage', chatMessageSchema);
// User Schema
const UserSchema = new mongoose.Schema({
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  email: { 
    type: String, 
    required: true, 
    unique: true,
    validate: {
      validator: function(v) {
        return /^[a-zA-Z0-9._%+-]+@iiit\.ac\.in$/.test(v);
      },
      message: props => `${props.value} is not a valid IIIT email!`
    }
  },
  age: { type: Number, required: true },
  contactNumber: { type: String, required: true },
  password: { type: String, required: true },
  cartCount: { type: Number, default: 0 }  // Added cart count field
});
const User = mongoose.model('User', UserSchema);
// Item Schema
const itemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, required: true },
  price: { type: Number, required: true },
  sellerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  stockQuantity: { type: Number, default: 0 },
  category: { 
    type: String, 
    required: true,
    enum: ['Electronics', 'Books', 'Clothing', 'Furniture', 'Stationery', 'Sports', 'Miscellaneous']
  },
  imageUrl: String
});
  
  const Item = mongoose.model('Item', itemSchema);

  const cartSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    items: [{
      itemId: { type: mongoose.Schema.Types.ObjectId, ref: 'Item', required: true },
      quantity: { type: Number, required: true, min: 1 }
    }]
  });
  
  const Cart = mongoose.model('Cart', cartSchema);
  
const orderSchema = new mongoose.Schema({
  buyerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  sellerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  itemId: { type: mongoose.Schema.Types.ObjectId, ref: 'Item', required: true },
  quantity: { type: Number, required: true },
  status: { type: String, enum: ['pending', 'completed'], default: 'pending' },
  otp: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

const Order = mongoose.model('Order', orderSchema);
// Middleware for token verification
const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.header('Authorization');
    
    if (!authHeader) {
      console.log("No auth header found");
      return res.status(401).json({ message: 'No token, authorization denied' });
    }
    const token = authHeader.replace('Bearer ', ''); 
    if (!token) {
      console.log("No token after Bearer removal");
      return res.status(401).json({ message: 'No token, authorization denied' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret');
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ message: 'Token is not valid' });
  }
};

const verifyRecaptcha = async (token) => {
  const secretKey = '6LcqOssqAAAAALKFELb6uZr2viccmeuy6wWl1p8U';
  const verifyUrl = `https://www.google.com/recaptcha/api/siteverify?secret=${secretKey}&response=${token}`;
  
  const response = await fetch(verifyUrl, { method: 'POST' });
  const data = await response.json();
  return data.success;
};
// Chat Support Routes
// Update the chat route in your index.js
app.post('/api/chat', verifyToken, async (req, res) => {
  try {
    const { message } = req.body;
    const sessionId = req.user.id;

    // Retrieve or create chat history
    let chatHistory = await ChatMessage.findOne({ sessionId });
    
    if (!chatHistory) {
      chatHistory = new ChatMessage({
        sessionId,
        messages: []
      });
    }

    // Add user message to database
    chatHistory.messages.push({
      role: 'user',
      content: message,
      timestamp: new Date()
    });

    // Initialize Gemini chat
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

    // Format chat history for Gemini
    const formattedHistory = chatHistory.messages.map(msg => ({
      role: msg.role === 'user' ? 'user' : 'model',
      parts: [{ text: msg.content }]
    }));

    // Create chat
    const chat = model.startChat({
      history: formattedHistory,
      generationConfig: {
        maxOutputTokens: 1000,
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
      },
    });

    // Send the current message
    const result = await chat.sendMessage(message);
    const response = await result.response;
    const botMessage = response.text();

    // Add bot response to database
    chatHistory.messages.push({
      role: 'bot',
      content: botMessage,
      timestamp: new Date()
    });

    // Update last activity timestamp and save
    chatHistory.lastUpdated = new Date();
    await chatHistory.save();

    res.json({ 
      response: botMessage,
      timestamp: new Date()
    });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ 
      error: 'An error occurred while processing your message',
      details: error.message 
    });
  }
});
// Get chat history
app.get('/api/chat/history', verifyToken, async (req, res) => {
  try {
    const sessionId = req.user.id;
    const chatHistory = await ChatMessage.findOne({ sessionId });
    
    if (!chatHistory) {
      return res.json({ messages: [] });
    }

    res.json({ messages: chatHistory.messages });
  } catch (error) {
    console.error('Error fetching chat history:', error);
    res.status(500).json({ error: 'Failed to fetch chat history' });
  }
});

// Clear chat history
app.delete('/api/chat/history', verifyToken, async (req, res) => {
  try {
    const sessionId = req.user.id;
    await ChatMessage.findOneAndDelete({ sessionId });
    res.json({ message: 'Chat history cleared successfully' });
  } catch (error) {
    console.error('Error clearing chat history:', error);
    res.status(500).json({ error: 'Failed to clear chat history' });
  }
});
// Registration Route
app.post('/api/register', async (req, res) => {
  try {
    const { firstName, lastName, email, age, contactNumber, password, recaptchaToken } = req.body;
    const isValidCaptcha = await verifyRecaptcha(recaptchaToken);
  if (!isValidCaptcha) {
    return res.status(400).json({ message: 'Invalid reCAPTCHA' });
  }

    // Check if user already exists
    let user = await User.findOne({ email });
    if (user) {
      return res.status(400).json({ message: 'User already exists' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create new user
    user = new User({
      firstName,
      lastName,
      email,
      age,
      contactNumber,
      password: hashedPassword
    });

    await user.save();

    res.status(201).json({ message: 'User registered successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login Route
app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Check if user exists
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Generate token
    const token = jwt.sign(
      { id: user._id, email: user.email }, 
      process.env.JWT_SECRET || 'your_jwt_secret', 
      { expiresIn: '1h' }
    );

    res.json({ 
      token, 
      user: { 
        id: user._id, 
        firstName: user.firstName, 
        lastName: user.lastName, 
        email: user.email 
      } 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Profile Route (Protected)
app.get('/api/profile', verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    res.json(user);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
// Item Routes
// Add item
app.get('/api/items', verifyToken, async (req, res) => {
  try {
    const { search, categories } = req.query;
    const currentUserId = req.user.id;
    const currentUserObjectId = new mongoose.Types.ObjectId(currentUserId.toString());
    let query = {
      sellerId: { $ne: currentUserObjectId  }
    };  // Start with empty query
    // Search by name (case insensitive)
    if (search) {
      query.name = { $regex: search, $options: 'i' };
    }

    // Filter by categories
    if (categories) {
      const categoryArray = categories.split(',');
      query.category = { $in: categoryArray };
    }

    // Find items and populate seller information
    const items = await Item.find(query)
      .populate('sellerId', 'firstName lastName')
      .exec();
    
    if (!items || items.length === 0) {
      console.log("No items found");
      return res.status(404).json({ message: "No items found" });
    }

    // Transform the response to include vendor name
    const transformedItems = items.map(item => ({
      _id: item._id,
      name: item.name,
      description: item.description,
      price: item.price,
      category: item.category,
      imageUrl: item.imageUrl,
      stockQuantity: item.stockQuantity,
      vendorName: item.sellerId ? `${item.sellerId.firstName} ${item.sellerId.lastName}` : 'Unknown Vendor'
    }));
    res.json(transformedItems);
  } catch (err) {
    console.error("Error in /api/items:", err);
    res.status(500).json({ message: "Error fetching items", error: err.message });
  }
});
app.get("/api/items/:id", async (req, res) => {
  const { id } = req.params;
  
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(400).json({ message: "Invalid item ID" });
  }

  try {
    const item = await Item.findById(id)
      .populate('sellerId', 'firstName lastName email')
      .exec();

    if (!item) {
      return res.status(404).json({ message: "Item not found" });
    }

    const transformedItem = {
      ...item.toObject(),
      vendorName: item.sellerId ? `${item.sellerId.firstName} ${item.sellerId.lastName}` : 'Unknown Vendor',
      vendorEmail: item.sellerId ? item.sellerId.email : 'unknown@email.com'
    };

    res.json(transformedItem);
  } catch (err) {
    console.error("Error in /api/items/:id:", err); // Add this for debugging
    res.status(500).json({ message: "Error fetching item", error: err.message });
  }
});


// POST create item (for testing)
app.post("/api/items", async (req, res) => {
  try {
    const newItem = new Item(req.body);
    await newItem.save();
    res.status(201).json(newItem);
  } catch (err) {
    console.error("Error in POST /api/items:", err); // Add this for debugging
    res.status(500).json({ message: "Error creating item", error: err.message });
  }
});
// Update the add to cart route to handle cart count
app.post('/api/cart/add', verifyToken, async (req, res) => {
  try {
    const { itemId, quantity } = req.body;
    const userId = req.user.id;

    // Find or create cart for user
    let cart = await Cart.findOne({ userId });
    if (!cart) {
      cart = new Cart({ userId, items: [] });
    }

    // Check if item already exists in cart
    const existingItemIndex = cart.items.findIndex(
      item => item.itemId.toString() === itemId
    );

    // Update user's cart count
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (existingItemIndex > -1) {
      // Update quantity if item exists
      cart.items[existingItemIndex].quantity += quantity;
    } else {
      // Add new item if it doesn't exist
      cart.items.push({ itemId, quantity });
      // Increment cart count only for new items
      user.cartCount += 1;
      await user.save();
    }

    await cart.save();
    
    // Return both cart and updated cart count
    res.json({
      cart,
      cartCount: user.cartCount
    });
  } catch (error) {
    console.error('Error adding to cart:', error);
    res.status(500).json({ message: 'Error adding item to cart' });
  }
});
// Add a new route to remove item from cart
app.delete('/api/cart/remove/:itemId', verifyToken, async (req, res) => {
  try {
    const { itemId } = req.params;
    const userId = req.user.id;

    // Find user's cart
    const cart = await Cart.findOne({ userId });
    if (!cart) {
      return res.status(404).json({ message: 'Cart not found' });
    }

    // Find user
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Remove item from cart
    cart.items = cart.items.filter(item => item.itemId.toString() !== itemId);
    await cart.save();

    // Decrement cart count
    user.cartCount = Math.max(0, user.cartCount - 1);
    await user.save();

    res.json({
      cart,
      cartCount: user.cartCount
    });
  } catch (error) {
    console.error('Error removing item from cart:', error);
    res.status(500).json({ message: 'Error removing item from cart' });
  }
});

// Update the get cart route to include cart count
app.get('/api/cart', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const cart = await Cart.findOne({ userId })
      .populate('items.itemId');
    
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (!cart) {
      return res.json({ 
        items: [],
        cartCount: user.cartCount
      });
    }

    res.json({
      cart,
      cartCount: user.cartCount
    });
  } catch (error) {
    res.status(500).json({ message: 'Error fetching cart' });
  }
});
// Add a route to clear cart
app.delete('/api/cart/clear', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;

    // Find user
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Clear cart
    await Cart.findOneAndDelete({ userId });

    // Reset cart count
    user.cartCount = 0;
    await user.save();

    res.json({
      message: 'Cart cleared successfully',
      cartCount: 0
    });
  } catch (error) {
    console.error('Error clearing cart:', error);
    res.status(500).json({ message: 'Error clearing cart' });
  }
});
// Place Order route
// Place Order route
app.post('/api/orders/place', verifyToken, async (req, res) => {
  try {
    const { items } = req.body;
    const buyerId = req.user.id;
    
    if (!items || !Array.isArray(items)) {
      return res.status(400).json({ message: 'Invalid items data' });
    }

    const orders = [];
    
    for (const item of items) {
      // Generate OTP first
      const plainOtp = Math.floor(100000 + Math.random() * 900000).toString();
      const hashedOtp = await bcrypt.hash(plainOtp, 10);
      
      // Verify item exists
      const dbItem = await Item.findById(item.itemId._id)
        .populate('sellerId', 'firstName lastName email');
      
      if (!dbItem) {
        continue; // Skip invalid items
      }

      const order = new Order({
        buyerId,
        sellerId: dbItem.sellerId._id,
        itemId: dbItem._id,
        quantity: item.quantity,
        otp: hashedOtp,
        status: 'pending'
      });
      
      await order.save();
      
      // Create a response object with the plain OTP
      const orderResponse = {
        _id: order._id,
        buyerId: order.buyerId,
        sellerId: dbItem.sellerId,
        itemId: dbItem,
        quantity: order.quantity,
        status: order.status,
        plainOtp: plainOtp // Include the plain OTP in response
      };
      
      orders.push(orderResponse);
    }

    // Clear the user's cart after successful order placement
    await Cart.findOneAndDelete({ userId: buyerId });
    await User.findByIdAndUpdate(buyerId, { cartCount: 0 });

    res.json({ 
      message: 'Orders placed successfully',
      orders: orders 
    });
  } catch (error) {
    console.error('Error placing order:', error);
    res.status(500).json({ message: 'Error placing order', error: error.message });
  }
});


// Get orders for buyer
app.get('/api/orders/buyer', verifyToken, async (req, res) => {
  try {
    const orders = await Order.find({ buyerId: req.user.id })
      .populate({
        path: 'itemId',
        select: 'name price description'
      })
      .populate({
        path: 'sellerId',
        select: 'firstName lastName email'
      })
      .populate({
        path: 'buyerId',
        select: 'firstName lastName email'
      })
      .sort({ createdAt: -1 });

    // For pending orders, re-generate plainOtp if needed
    const processedOrders = orders.map(order => {
      const orderObj = order.toObject();
      if (order.status === 'pending') {
        orderObj.plainOtp = order.plainOtp; // Include the plainOtp for pending orders
      }
      return orderObj;
    });

    res.json(processedOrders);
  } catch (error) {
    console.error('Error fetching buyer orders:', error);
    res.status(500).json({ message: 'Error fetching orders' });
  }
});
// Get orders for seller
app.get('/api/orders/seller', verifyToken, async (req, res) => {
  try {
    const orders = await Order.find({ sellerId: req.user.id })
      .populate({
        path: 'itemId',
        select: 'name price description'
      })
      .populate({
        path: 'sellerId',
        select: 'firstName lastName email'
      })
      .populate({
        path: 'buyerId',
        select: 'firstName lastName email'
      })
      .sort({ createdAt: -1 });

    res.json(orders);
  } catch (error) {
    console.error('Error fetching seller orders:', error);
    res.status(500).json({ message: 'Error fetching orders' });
  }
});
// Verify OTP and complete order
app.post('/api/orders/complete', verifyToken, async (req, res) => {
  try {
    const { orderId, otp } = req.body;
    
    if (!orderId || !otp) {
      return res.status(400).json({ message: 'Order ID and OTP are required' });
    }

    const order = await Order.findById(orderId)
      .populate('itemId')
      .populate('sellerId', 'firstName lastName email')
      .populate('buyerId', 'firstName lastName email');
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    // Verify the seller is the one completing the order
    if (order.sellerId._id.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Unauthorized to complete this order' });
    }
    
    const isValidOtp = await bcrypt.compare(otp, order.otp);
    if (!isValidOtp) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }
    
    order.status = 'completed';
    await order.save();
    
    res.json({ 
      message: 'Order completed successfully',
      order: order
    });
  } catch (error) {
    console.error('Error completing order:', error);
    res.status(500).json({ message: 'Error completing order' });
  }
});
// Add this route to your backend index.js
app.post('/api/orders/regenerate-otp/:orderId', verifyToken, async (req, res) => {
  try {
    const { orderId } = req.params;
    
    // Find the order
    const order = await Order.findById(orderId);
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    // Verify that the requester is the buyer
    if (order.buyerId.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Unauthorized to regenerate OTP for this order' });
    }
    
    // Check if order is still pending
    if (order.status !== 'pending') {
      return res.status(400).json({ message: 'Can only regenerate OTP for pending orders' });
    }
    
    // Generate new OTP
    const newPlainOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const newHashedOtp = await bcrypt.hash(newPlainOtp, 10);
    
    // Update order with new OTP
    order.otp = newHashedOtp;
    await order.save();
    
    res.json({
      message: 'OTP regenerated successfully',
      orderId: order._id,
      plainOtp: newPlainOtp
    });
  } catch (error) {
    console.error('Error regenerating OTP:', error);
    res.status(500).json({ message: 'Error regenerating OTP' });
  }
});
  // Profile Update Route (Protected)
app.put('/api/profile', verifyToken, async (req, res) => {
  try {
    const { firstName, lastName, email, age, contactNumber } = req.body;
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Update user profile
    user.firstName = firstName || user.firstName;
    user.lastName = lastName || user.lastName;
    user.email = email || user.email;
    user.age = age || user.age;
    user.contactNumber = contactNumber || user.contactNumber;

    await user.save();
    res.json(user); // Return the updated user profile
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});
