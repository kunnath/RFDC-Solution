-- Dummy SQL for DB test
CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO users (name) VALUES ('Alice'), ('Bob');
SELECT * FROM users;
