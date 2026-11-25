import { neon } from '@neondatabase/serverless';

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ ok: false, error: 'DATABASE_URL is not configured' });
  }
  try {
    const sql = neon(process.env.DATABASE_URL);
    const rows = await sql`select current_database() as database, now() as server_time`;
    return res.status(200).json({ ok: true, database: rows[0].database, serverTime: rows[0].server_time });
  } catch (error) {
    console.error('Neon health check failed:', error?.message || error);
    return res.status(500).json({ ok: false, error: 'Neon connection failed' });
  }
}
