// ─────────────────────────────────────────────
// Prometheus Metrics Middleware
// Uses prom-client to track:
//   - HTTP request count (by route, method, status)
//   - HTTP response duration (histogram)
//   - Default Node.js metrics (CPU, memory, event loop)
// ─────────────────────────────────────────────

const client = require("prom-client");

// Collect default Node.js metrics automatically
// Includes: CPU usage, memory heap, event loop lag, GC stats
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// ── Custom Metric 1: HTTP Request Counter ──
// Counts total requests grouped by method, route, status code
const httpRequestCounter = new client.Counter({
    name: "http_requests_total",
    help: "Total number of HTTP requests",
    labelNames: ["method", "route", "status_code"],
    registers: [register],
});

// ── Custom Metric 2: HTTP Response Duration Histogram ──
// Tracks how long each request takes (in seconds)
// Buckets: 10ms, 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s
const httpRequestDuration = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "Duration of HTTP requests in seconds",
    labelNames: ["method", "route", "status_code"],
    buckets: [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5],
    registers: [register],
});

// ── Custom Metric 3: Active Connections Gauge ──
// Tracks how many requests are currently being processed
const activeConnections = new client.Gauge({
    name: "http_active_connections",
    help: "Number of active HTTP connections",
    registers: [register],
});

// ── Express Middleware ──
// Attach this before your routes in server.js
const metricsMiddleware = (req, res, next) => {
    // Skip tracking the /metrics endpoint itself
    if (req.path === "/metrics") return next();

    const start = Date.now();
    activeConnections.inc();

    // When response finishes, record metrics
    res.on("finish", () => {
        const duration = (Date.now() - start) / 1000; // convert ms → seconds

        // Normalize route: replace IDs like /api/files/abc123 → /api/files/:id
        const route = req.route ? req.baseUrl + req.route.path : req.path;

        httpRequestCounter.inc({
            method: req.method,
            route,
            status_code: res.statusCode,
        });

        httpRequestDuration.observe(
            { method: req.method, route, status_code: res.statusCode },
            duration
        );

        activeConnections.dec();
    });

    next();
};

module.exports = { metricsMiddleware, register };
