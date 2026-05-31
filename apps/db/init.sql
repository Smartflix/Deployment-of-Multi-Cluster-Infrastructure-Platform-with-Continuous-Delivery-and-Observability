CREATE TABLE IF NOT EXISTS app_health (
  id integer PRIMARY KEY,
  status text NOT NULL,
  checked_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO app_health (id, status)
VALUES (1, 'ok')
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  checked_at = now();
