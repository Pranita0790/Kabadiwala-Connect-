-- =====================================================================
-- 009 — Allow household USER role on users.role
-- Mirrors packages/shared/contracts/enums.json -> userRole.USER
-- =====================================================================

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('COLLECTOR', 'USER', 'RECYCLER', 'ADMIN'));
