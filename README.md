# RythuMithra Agri ERP — V2.0

**Business:** RYTHUMITHRA FERTILIZERS, PESTICIDES & SEEDS  
**Application:** RythuMithra Agri ERP

Offline-first inventory and billing application designed for GitHub Pages with optional Supabase cloud synchronization.

## V2 features

- Product master with HSN, pack size, unit and reorder level
- Batch-level inventory with manufacturing/expiry dates
- Cost price, MRP and selling price kept separate
- Purchase entry increases stock and creates an audit movement
- Sales billing decreases stock and prints MRP + selling price; cost price is never printed
- GST rate is stored with each batch; supports arbitrary percentage input, with presets 0/5/12/18/28
- Intra-state CGST/SGST and interstate IGST calculation
- Earliest-expiry batch suggestion (FEFO)
- Sales history, invoice cancellation and stock restoration
- Sales return and damage movement foundation
- Inventory search by product, HSN or batch
- Expiry and low-stock filters
- A4 print-ready invoice branded with RYTHUMITHRA FERTILIZERS, PESTICIDES & SEEDS
- Local IndexedDB persistence via Dexie
- Optional Supabase authentication and cloud synchronization foundation
- Supabase schema including RLS, Realtime tables and atomic stock-decrement RPC
- GitHub Actions deployment to GitHub Pages

## Run locally

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## GitHub Pages

The repository is configured for a repository named `rythumithra-agri-erp` and uses `/rythumithra-agri-erp/` as Vite's base path. If you choose another repository name, change `base` in `vite.config.ts` and the manifest path in `index.html`.

The included workflow deploys `dist` to GitHub Pages on pushes to `main`.

## Supabase

1. Create a Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL editor.
3. Enable email/password authentication.
4. Add GitHub repository Actions secrets:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
5. Push to `main`.

Never put a Supabase `service_role` key in frontend code or GitHub Pages.

### Important synchronization note

V2 contains the cloud schema, authentication, local persistence and a manual cloud sync path. The next hardening release should replace broad upsert synchronization with an append-only outbox and server-side transaction/reconciliation workflow for fully safe offline multi-device conflict resolution. The included `post_sale_item` RPC is the starting point for atomic stock validation.
