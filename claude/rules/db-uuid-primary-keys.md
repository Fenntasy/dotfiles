---
paths:
  - db/migrations/**
  - app/queries/**
  - app/db/**
---

# UUID Primary Keys

All tables use UUID primary keys. Auto-increment integers are never used.

## Rules

- Never use `AUTO_INCREMENT`, `SERIAL`, or any database-generated sequential integer as a primary key
- All `id` columns must be a UUID type appropriate for the database (`CHAR(36)`, `UUID`, etc.)
- Foreign key columns referencing UUID primary keys must use the same UUID column type
- Always generate UUIDs in application code with `crypto.randomUUID()` — never use database functions (`UUID()`, `gen_random_uuid()`) to generate IDs for application rows
- Pass the generated UUID explicitly in INSERT statements
- All TypeScript types for table `id` fields and FK columns must be `string`, never `number`

## Why

Auto-increment IDs expose record counts, creation order, and growth rate. They enable trivial enumeration of resources and leak business information. UUIDs prevent this and allow IDs to be generated before the DB round-trip, making application code simpler and portable across databases.

## Examples

```ts
// CORRECT — generate in app code, pass explicitly
const id = crypto.randomUUID();
await db.query("INSERT INTO petitions (id, ...) VALUES (?, ...)", [id, ...]);
return { id };

// WRONG — database-generated sequential integer
await db.query("INSERT INTO petitions (...) VALUES (...)");
return { id: result.insertId }; // exposes row count, enumerable

// WRONG — database-generated UUID (ties ID generation to DB, not portable)
await db.query("INSERT INTO petitions (id, ...) VALUES (gen_random_uuid(), ...)");
```
