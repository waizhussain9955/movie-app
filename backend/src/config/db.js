const mongoose = require('mongoose');

async function connectDB() {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/streammax';
  try {
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 3000,
    });
    console.log('✅ MongoDB connected successfully to:', uri);
  } catch (error) {
    console.warn('⚠️ Local MongoDB connection failed or offline:', error.message);
    console.warn('ℹ️ Running in memory cache mode for movie streams and metadata.');
  }
}

module.exports = { connectDB };

