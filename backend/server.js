require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

const authRoutes = require("./routes/auth");
const fileRoutes = require("./routes/files");
const blogRoutes = require("./routes/blogs");

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/files", fileRoutes);
app.use("/api/blogs", blogRoutes);

// Health check endpoint — used by Kubernetes liveness/readiness probes
// Returns 200 when the server is up and DB is connected
app.get("/api/health", (req, res) => {
  const dbState = mongoose.connection.readyState;
  // 1 = connected, 2 = connecting
  if (dbState === 1 || dbState === 2) {
    res.status(200).json({ status: "ok", db: "connected" });
  } else {
    res.status(503).json({ status: "error", db: "disconnected" });
  }
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