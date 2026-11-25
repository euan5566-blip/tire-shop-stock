import { neon } from '@neondatabase/serverless';
import bcrypt from 'bcryptjs';
import { SignJWT } from 'jose';
import { authSecret, setSessionCookie } from '../_auth.js';

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  if (!email || !password || password.length > 200) {
    return res.status(400).json({ ok: false, error: 'กรุณากรอกอีเมลและรหัสผ่าน' });
  }
  if (!process.env.DATABASE_URL) return res.status(503).json({ ok: false, error: 'DATABASE_URL is not configured' });
  try {
    const sql = neon(process.env.DATABASE_URL);
    await sql`
      CREATE TABLE IF NOT EXISTS public.app_users (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        email text NOT NULL UNIQUE,
        password_hash text NOT NULL,
        full_name text NOT NULL DEFAULT '',
        role text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner','manager','staff')),
        active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      )
    `;
    let [account] = await sql`SELECT id, email, password_hash, full_name, role, active FROM public.app_users WHERE email = ${email} LIMIT 1`;
    // Create only the configured owner account; there is no public registration endpoint.
    if (!account && process.env.OWNER_EMAIL && process.env.OWNER_PASSWORD) {
      const ownerEmail = process.env.OWNER_EMAIL.trim().toLowerCase();
      if (email === ownerEmail) {
        const hash = await bcrypt.hash(process.env.OWNER_PASSWORD, 12);
        const name = process.env.OWNER_NAME || 'Owner';
        const inserted = await sql`
          INSERT INTO public.app_users (email, password_hash, full_name, role)
          VALUES (${ownerEmail}, ${hash}, ${name}, 'owner')
          ON CONFLICT (email) DO NOTHING
          RETURNING id, email, password_hash, full_name, role, active
        `;
        account = inserted[0] || (await sql`SELECT id, email, password_hash, full_name, role, active FROM public.app_users WHERE email = ${email} LIMIT 1`)[0];
      }
    }
    if (!account || !account.active || !(await bcrypt.compare(password, account.password_hash))) {
      return res.status(401).json({ ok: false, error: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
    }
    const token = await new SignJWT({ email: account.email, role: account.role })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(account.id)
      .setIssuedAt()
      .setExpirationTime('12h')
      .sign(authSecret());
    setSessionCookie(res, token);
    return res.status(200).json({ ok: true, user: { id: account.id, email: account.email, name: account.full_name, role: account.role } });
  } catch (error) {
    console.error('Login failed:', error?.message || error);
    return res.status(500).json({ ok: false, error: 'ระบบเข้าสู่ระบบขัดข้อง กรุณาตรวจสอบการตั้งค่าเซิร์ฟเวอร์' });
  }
}
