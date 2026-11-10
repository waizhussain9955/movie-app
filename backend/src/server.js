require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { connectDB } = require('./config/db');
const movieRoutes = require('./routes/movieRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    service: 'StreamMax API Server',
    database: 'MongoDB',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/api', movieRoutes);

// Start Server
async function startServer() {
  await connectDB();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 StreamMax Backend is running live at: http://localhost:${PORT}`);
    console.log(`📡 Health Check: http://localhost:${PORT}/api/health`);
    console.log(`🎬 Home Feed: http://localhost:${PORT}/api/home`);
    console.log(`🔍 Search Example: http://localhost:${PORT}/api/search?q=spider-man`);
  });
}

if (require.main === module) {
  startServer();
}

module.exports = app;

