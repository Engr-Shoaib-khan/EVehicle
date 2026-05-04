const mongoose = require("mongoose");

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      // These are the recommended options for Mongoose 7+
      // (useNewUrlParser and useUnifiedTopology are defaults now, no need to set)
    });

    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌ MongoDB Connection Error: ${error.message}`);
    process.exit(1); // Kill process — app cannot run without DB
  }
};

module.exports = connectDB;
