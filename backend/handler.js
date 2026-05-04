const serverless = require("serverless-http");
const app = require("./app");
const connectDB = require("./config/db");

// Lambda handler
module.exports.handler = async (event, context) => {
  // Ensure DB is connected
  context.callbackWaitsForEmptyEventLoop = false;
  await connectDB();
  
  const handler = serverless(app);
  return await handler(event, context);
};
