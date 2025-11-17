-- Demo accounts for testing transfers and tracing
-- Must include created_at and updated_at since they are NOT NULL
INSERT INTO accounts (account_number, account_holder_name, balance, currency, status, created_at, updated_at) 
VALUES 
  ('ACC001', 'Alice Smith', 5000.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC002', 'Bob Jones', 3000.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC003', 'Charlie Brown', 7500.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC004', 'Diana Prince', 2000.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC005', 'Eve Davis', 10000.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC006', 'Frank Miller', 4500.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC007', 'Grace Lee', 6000.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC008', 'Henry Ford', 8500.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC009', 'Ivy Chen', 1500.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('ACC010', 'Jack Ryan', 9500.00, 'USD', 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);