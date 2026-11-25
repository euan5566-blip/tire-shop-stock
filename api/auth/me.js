import { readSession } from '../_auth.js';

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }
  try {
    const user = await readSession(req);
    return res.status(200).json({ ok: true, user });
  } catch (error) {
    console.error('Session check failed:', error?.message || error);
    return res.status(503).json({ ok: false, error: 'Authentication is not configured' });
  }
}
