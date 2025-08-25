const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const fileRoutes = require('./routes/files');
const blogRoutes = require('./routes/blogs');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/blogs', blogRoutes);

// Database connection
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Drop the problematic username index if it exists
    try {
      const db = mongoose.connection.db;
      const collections = await db.listCollections().toArray();
      const usersCollection = collections.find(col => col.name === 'users');
      
      if (usersCollection) {
        const indexes = await db.collection('users').indexes();
        const usernameIndex = indexes.find(index => 
          index.key && index.key.username === 1
        );
        
        if (usernameIndex) {
          await db.collection('users').dropIndex('username_1');
          console.log('Dropped problematic username index');
        }
        
        // Clean up any existing users with null or invalid data
        const result = await db.collection('users').deleteMany({
          $or: [
            { email: null },
            { email: { $exists: false } },
            { username: { $exists: true } }
          ]
        });
        
        if (result.deletedCount > 0) {
          console.log(`Cleaned up ${result.deletedCount} invalid user records`);
        }
      }
    } catch (error) {
      console.log('Database cleanup completed or not needed');
    }
    
    const PORT = process.env.PORT || 5000;
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
  }); 