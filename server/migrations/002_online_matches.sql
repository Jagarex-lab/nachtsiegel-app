-- Local transport fixture schema. Initialized idempotently by MatchService.
CREATE TABLE IF NOT EXISTS online_matches (
 id TEXT PRIMARY KEY, player_a TEXT NOT NULL REFERENCES users(id), player_b TEXT NOT NULL REFERENCES users(id),
 status TEXT NOT NULL CHECK(status IN ('waiting_ready','active','finished','cancelled')),
 state TEXT NOT NULL, server_seed TEXT NOT NULL, rule_version TEXT NOT NULL, catalog_version TEXT NOT NULL,
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deadline INTEGER NOT NULL, result TEXT,
 CHECK(player_a <> player_b)
);
CREATE INDEX IF NOT EXISTS online_matches_a ON online_matches(player_a,created_at);
CREATE INDEX IF NOT EXISTS online_matches_b ON online_matches(player_b,created_at);
CREATE TABLE IF NOT EXISTS online_match_players (
 match_id TEXT NOT NULL REFERENCES online_matches(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id),
 ready INTEGER NOT NULL DEFAULT 0, action_sequence INTEGER NOT NULL DEFAULT 0,
 connected INTEGER NOT NULL DEFAULT 0, disconnect_deadline INTEGER,
 PRIMARY KEY(match_id,user_id)
);
CREATE TABLE IF NOT EXISTS online_match_events (
 match_id TEXT NOT NULL REFERENCES online_matches(id) ON DELETE CASCADE, sequence INTEGER NOT NULL,
 event TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(match_id,sequence)
);
CREATE TABLE IF NOT EXISTS online_match_actions (
 match_id TEXT NOT NULL REFERENCES online_matches(id) ON DELETE CASCADE, sequence INTEGER NOT NULL,
 user_id TEXT NOT NULL REFERENCES users(id), action TEXT NOT NULL, request_id TEXT NOT NULL,
 PRIMARY KEY(match_id,sequence)
);
CREATE TABLE IF NOT EXISTS online_requests (
 user_id TEXT NOT NULL REFERENCES users(id), request_id TEXT NOT NULL, body_hash TEXT NOT NULL,
 response TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(user_id,request_id)
);
CREATE INDEX IF NOT EXISTS online_requests_created ON online_requests(created_at);
CREATE TABLE IF NOT EXISTS online_matchmaking_entries (
 user_id TEXT PRIMARY KEY REFERENCES users(id), region TEXT NOT NULL, rating INTEGER NOT NULL,
 joined_at INTEGER NOT NULL, expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS online_queue_region ON online_matchmaking_entries(region,joined_at);
CREATE TABLE IF NOT EXISTS online_private_invites (
 code_hash TEXT PRIMARY KEY, creator_id TEXT UNIQUE NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL
);
