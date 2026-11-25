import { betterAuth } from "better-auth";
import { PostgresDialect } from "kysely";
import { Pool } from "pg";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is not configured");
}

const authPool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,
  idleTimeoutMillis: 10_000,
  connectionTimeoutMillis: 10_000,
  options: "-c search_path=auth"
});

const appUrl = process.env.APP_URL || process.env.VERCEL_URL && `https://${process.env.VERCEL_URL}`;

export const auth = betterAuth({
  appName: "Xayathep Tire Shop",
  baseURL: process.env.BETTER_AUTH_URL || appUrl,
  secret: process.env.BETTER_AUTH_SECRET,
  trustedOrigins: appUrl ? [appUrl] : [],
  database: {
    dialect: new PostgresDialect({ pool: authPool }),
    type: "postgres",
    schemaName: "auth"
  },
  emailAndPassword: {
    enabled: true,
    disableSignUp: true,
    minPasswordLength: 8
  },
  session: {
    expiresIn: 60 * 60 * 24 * 7,
    updateAge: 60 * 60 * 24
  },
  advanced: {
    database: {
      generateId: () => crypto.randomUUID()
    },
    useSecureCookies: process.env.NODE_ENV === "production"
  }
});
