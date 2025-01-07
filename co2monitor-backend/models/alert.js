const mongoose = require('mongoose');

// Define the schema for the Alert model
const alertSchema = new mongoose.Schema({
  topic: {
    type: String,
    required: [true, 'Topic is required'],
  },
  port: {
    type: Number,
    required: [true, 'Port is required'],
  },
  co2Limit: {
    type: Number,
    required: [true, 'CO2 limit is required'],
  },
  broker: {
    type: String,
    required: [true, 'Broker string is required'],
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Create the Alert model
module.exports = mongoose.model('Alert', alertSchema);
