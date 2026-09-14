import { db } from './db'
import { supabase, cloudEnabled } from './supabase'
import type {
  Product,
  ProductBatch,
  Customer,
  Supplier,
  PurchaseInvoice,
  PurchaseItem,
  SalesInvoice,
  SalesItem,
  SalesReturn,
  SalesReturnItem,
  InventoryMovement,
} from '../types'

const snake = (key: string) => key.replace(/[A-Z]/g, (match) => `_${match.toLowerCase()}`)
const camel = (key: string) => key.replace(/_([a-z])/g, (_, char: string) => char.toUpperCase())

function encodeRow<T extends object>(row: T): Record<string, unknown> {
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [snake(key), value]))
}

function decodeRow<T>(row: Record<string, unknown>): T {
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [camel(key), value])) as T
}

async function push<T extends object>(table: string, rows: T[]) {
  if (!rows.length) return
  const { error } = await supabase!.from(table).upsert(rows.map(encodeRow), { onConflict: 'id' })
  if (error) throw error
}

async function pull<T>(table: string): Promise<T[]> {
  const { data, error } = await supabase!.from(table).select('*')
  if (error) throw error
  return (data ?? []).map((row) => decodeRow<T>(row as Record<string, unknown>))
}

export async function syncNow() {
  if (!cloudEnabled || !supabase) throw new Error('Supabase is not configured.')

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) throw new Error('Sign in to synchronize.')

  // Push the local snapshot first. This is the V2 manual-sync path.
  await push('products', await db.products.toArray())
  await push('product_batches', await db.batches.toArray())
  await push('customers', await db.customers.toArray())
  await push('suppliers', await db.suppliers.toArray())
  await push('purchase_invoices', await db.purchases.toArray())
  await push('purchase_items', await db.purchaseItems.toArray())
  await push('sales_invoices', await db.sales.toArray())
  await push('sales_items', await db.salesItems.toArray())
  await push('sales_returns', await db.returns.toArray())
  await push('sales_return_items', await db.returnItems.toArray())
  await push('inventory_movements', await db.movements.toArray())

  const [products, batches, customers, suppliers, purchases, purchaseItems, sales, salesItems, returns, returnItems, movements] =
    await Promise.all([
      pull<Product>('products'),
      pull<ProductBatch>('product_batches'),
      pull<Customer>('customers'),
      pull<Supplier>('suppliers'),
      pull<PurchaseInvoice>('purchase_invoices'),
      pull<PurchaseItem>('purchase_items'),
      pull<SalesInvoice>('sales_invoices'),
      pull<SalesItem>('sales_items'),
      pull<SalesReturn>('sales_returns'),
      pull<SalesReturnItem>('sales_return_items'),
      pull<InventoryMovement>('inventory_movements'),
    ])

  // Dexie supports an array of tables for a transaction; this also avoids the
  // TypeScript overload limit when more than five tables are involved.
  await db.transaction(
    'rw',
    [
      db.products,
      db.batches,
      db.customers,
      db.suppliers,
      db.purchases,
      db.purchaseItems,
      db.sales,
      db.salesItems,
      db.returns,
      db.returnItems,
      db.movements,
    ],
    async () => {
      await db.products.bulkPut(products)
      await db.batches.bulkPut(batches)
      await db.customers.bulkPut(customers)
      await db.suppliers.bulkPut(suppliers)
      await db.purchases.bulkPut(purchases)
      await db.purchaseItems.bulkPut(purchaseItems)
      await db.sales.bulkPut(sales)
      await db.salesItems.bulkPut(salesItems)
      await db.returns.bulkPut(returns)
      await db.returnItems.bulkPut(returnItems)
      await db.movements.bulkPut(movements)
    },
  )

  return {
    products: products.length,
    batches: batches.length,
    sales: sales.length,
    purchases: purchases.length,
  }
}
