-- V22: Buat UNIQUE constraint di staging_pump_items jadi DEFERRABLE
-- Root cause: UPDATE SET role_order = role_order + 1 pada multiple rows di satu statement
-- bisa tabrakan dengan UNIQUE(group_id, period, role_order) karena PostgreSQL check per-row.
-- DEFERRABLE INITIALLY DEFERRED = check saat COMMIT, bukan per-statement.
-- Fix bug 500 saat move/reorder pump.

ALTER TABLE staging_pump_items
  DROP CONSTRAINT IF EXISTS staging_pump_items_group_id_period_role_order_key;

ALTER TABLE staging_pump_items
  ADD CONSTRAINT staging_pump_items_group_id_period_role_order_key
  UNIQUE(group_id, period, role_order) DEFERRABLE INITIALLY DEFERRED;
