require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

const authRoutes = require("./routes/auth");
const fileRoutes = require("./routes/files");
const blogRoutes = require("./routes/blogs");

// Prometheus metrics middleware
const { metricsMiddleware, register } = require("./middleware/metrics");

const app = express();

// Middleware
// Allow requests from local dev and the deployed Vercel frontend
const allowedOrigins = [
  "http://localhost:5173",
  "http://localhost:3000",
  process.env.FRONTEND_URL, // set this in Vercel env vars after frontend deploy
].filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      // allow requests with no origin (mobile apps, curl, Postman)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin) || origin.endsWith(".vercel.app")) {
        return callback(null, true);
      }
      callback(new Error("Not allowed by CORS"));
    },
    credentials: true,
  })
);
app.use(express.json());

// Attach metrics tracking to all routes
// Must be before route definitions
app.use(metricsMiddleware);

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/files", fileRoutes);
app.use("/api/blogs", blogRoutes);

// Health check endpoint — used by Kubernetes liveness/readiness probes
app.get("/api/health", (req, res) => {
  const dbState = mongoose.connection.readyState;
  if (dbState === 1 || dbState === 2) {
    res.status(200).json({ status: "ok", db: "connected" });
  } else {
    res.status(503).json({ status: "error", db: "disconnected" });
  }
});

// Prometheus metrics endpoint
// Scraped by Prometheus every 15 seconds
// Returns all metrics in Prometheus text format
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

// MongoDB Connection
mongoose
  .connect(process.env.MONGO_URI)
  .then(async () => {
    console.log("Connected to MongoDB");

    try {
      const db = mongoose.connection.db;

      const collections = await db.listCollections().toArray();
      const usersCollection = collections.find((col) => col.name === "users");

      if (usersCollection) {
        const indexes = await db.collection("users").indexes();

        const usernameIndex = indexes.find(
          (index) => index.key && index.key.username === 1
        );

        if (usernameIndex) {
          await db.collection("users").dropIndex("username_1");
          console.log("Dropped problematic username index");
        }

        const result = await db.collection("users").deleteMany({
          $or: [
            { email: null },
            { email: { $exists: false } },
            { username: { $exists: true } },
          ],
        });

        if (result.deletedCount > 0) {
          console.log(`Cleaned up ${result.deletedCount} invalid user records`);
        }
      }
    } catch (error) {
      console.log("Database cleanup completed or not needed");
    }

    const PORT = process.env.PORT || 5000;

    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error("MongoDB connection error:", error);
  });