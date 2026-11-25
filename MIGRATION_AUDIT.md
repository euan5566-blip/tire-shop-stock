# Supabase Replacement Migration Audit

## Scope and safety

- Target branch: `migration/neon-better-auth`
- Base: `main`
- Production branch and Vercel production have not been changed.
- This audit is documentation only. It does not switch the live app or disable Supabase.
- Target architecture selected: Vercel hosting + Neon PostgreSQL + Better Auth + server-side API.

## Repository baseline inspected

- The app is a single-page HTML/JavaScript application in `index.html`.
- The checked branch baseline directly loads `@supabase/supabase-js@2` from jsDelivr and creates a browser Supabase client.
- Data access helpers call Supabase directly (`select`, `insert`, `update`), and pages use direct table queries.
- `package.json` currently has Vite scripts and React dependencies, but the app itself is a vanilla HTML/JS application.
- No `vercel.json`, `vite.config.js`, or `.vercel/project.json` was found at the repository root in this branch.

## SQL file inspection

### `supabase-new-schema.sql`

- 33 public tables.
- 9 sequences.
- 58 foreign-key declarations.
- 103 total constraint declarations/additions counted in the dump.
- 11 index declarations.
- Schema only: no COPY data blocks, functions, triggers, or policies.

### `tire-shop-neon-import.sql`

- Same 33 public tables, 9 sequences, 58 foreign-key declarations, 103 constraints, and 11 indexes.
- Includes COPY data blocks for all 33 tables.
- Row counts parsed from COPY blocks:

| Table | Rows |
|---|---:|
| activity_logs | 0 |
| app_settings | 1 |
| categories | 5 |
| customer_special_orders | 1 |
| customers | 2 |
| exchange_rates | 4 |
| expenses | 0 |
| inventory_orders | 1 |
| invoices | 0 |
| online_order_events | 0 |
| online_order_items | 6 |
| online_orders | 2 |
| products | 182 |
| profiles | 2 |
| purchase_items | 0 |
| purchase_orders | 6 |
| quotation_items | 2 |
| quotations | 1 |
| repair_order_items | 1 |
| repair_order_payments | 1 |
| repair_orders | 1 |
| return_items | 11 |
| returns | 6 |
| sale_items | 37 |
| sale_payments | 25 |
| sales | 25 |
| service_catalog | 0 |
| staff_payments | 0 |
| stock_movements | 63 |
| supplier_payments | 5 |
| suppliers | 2 |
| vehicles | 1 |
| warranty_records | 0 |

### Cluster backup

- Gzip expands to a PostgreSQL cluster SQL dump (~738 KB, 13,426 lines).
- Contains Supabase platform schemas/roles in addition to the shop database objects.
- Raw statement counts in the dump: 97 CREATE FUNCTION statements, 26 CREATE TRIGGER statements, 90 CREATE POLICY statements. These include Supabase Auth, Storage, Realtime, extension/platform objects and repeated/overloaded functions; they must not be copied wholesale into Neon.
- The cluster dump is a reference for identifying shop-specific business logic, not a safe direct restore script for Neon.

## Critical reconciliation item

The import SQL contains 25 rows in `sales` and 25 rows in `sale_payments`. A previous import verification reported 13 sales. Before any production data migration, reconcile IDs and timestamps between the source backup, import SQL, and current Neon database. Do not overwrite or merge blindly.

## Migration design

1. Preserve current Vercel production and existing Supabase project during development.
2. Build a server-side API in the Vercel project. The browser must not connect directly to Neon.
3. Add Better Auth backed by Neon; create the owner account securely and keep staff role changes server-authorized.
4. Port only shop-specific business logic from the cluster dump, including sale/purchase workflows and stock consistency. Reimplement Supabase-specific auth helpers and RLS policies as server-side authorization checks.
5. Migrate all 33 public tables with deterministic ID preservation, sequence reset, foreign-key validation, and row-count checks.
6. Inventory Storage buckets and object paths separately; move image files and verify every referenced object.
7. Test login, roles, products, sales, returns, purchase receiving, repair orders, expenses, receivables/payables, reports, backup/restore, and mobile/iPad layout in a Vercel Preview deployment.
8. Switch production only after acceptance tests pass and a final backup is verified.

## Not yet complete

This branch is not a ready-to-use replacement yet. No Neon connection, Better Auth implementation, API routes, data cutover, or production switch has been made. Keep Supabase active until all preview tests pass.
