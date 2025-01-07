const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// Define the schema for the User model
const userSchema = new mongoose.Schema({
  fullName: {
    type: String,
    required: [true, 'Full name is required'],

  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    match: [/\S+@\S+\.\S+/, 'Please use a valid email address'],
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [6, 'Password must be at least 6 characters long'],
  },
  alerts: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Alert', // This refers to the Alert model
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  },
});



// Create the User model
module.exports = mongoose.model('User', userSchema);

