import { getPool } from "../server/db.js";

export default async function handler(_req, res) {
  try {
    const result = await getPool().query("select current_timestamp as database_time");
    res.status(200).json({
      ok: true,
      service: "tire-shop-stock-api",
      database: "connected",
      timestamp: result.rows[0].database_time
    });
  } catch (error) {
    console.error("Health check failed", error);
    res.status(503).json({
      ok: false,
      service: "tire-shop-stock-api",
      database: "unavailable",
      message: process.env.NODE_ENV === "production"
        ? "Database connection is not ready"
        : error.message
    });
  }
}
