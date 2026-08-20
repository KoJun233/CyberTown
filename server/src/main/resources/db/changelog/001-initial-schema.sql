--liquibase formatted sql

--changeset cybertown:001
CREATE TABLE invite_code (
    id TEXT PRIMARY KEY,
    code_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'USED', 'REVOKED')),
    used_by_account_id TEXT,
    created_at TEXT NOT NULL,
    used_at TEXT
);

CREATE TABLE account (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    recovery_code_hash TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'MUTED', 'BANNED', 'DELETED')),
    privacy_accepted_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE resident (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL UNIQUE REFERENCES account(id),
    display_name TEXT NOT NULL,
    background_key TEXT NOT NULL,
    personality_social INTEGER NOT NULL,
    personality_curiosity INTEGER NOT NULL,
    personality_order INTEGER NOT NULL,
    appearance_seed INTEGER NOT NULL,
    coins INTEGER NOT NULL DEFAULT 100,
    energy INTEGER NOT NULL DEFAULT 100,
    mood INTEGER NOT NULL DEFAULT 60,
    location_key TEXT NOT NULL DEFAULT 'residential',
    control_mode TEXT NOT NULL DEFAULT 'AI' CHECK (control_mode IN ('AI', 'PLAYER')),
    last_active_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE access_session (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES account(id),
    access_token_hash TEXT NOT NULL UNIQUE,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    access_expires_at TEXT NOT NULL,
    refresh_expires_at TEXT NOT NULL,
    revoked_at TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE daily_goal (
    id TEXT PRIMARY KEY,
    resident_id TEXT NOT NULL REFERENCES resident(id),
    town_date TEXT NOT NULL,
    raw_instruction TEXT NOT NULL,
    structured_goal TEXT NOT NULL,
    constraints_json TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    UNIQUE (resident_id, town_date)
);

CREATE TABLE resident_action (
    id TEXT PRIMARY KEY,
    resident_id TEXT NOT NULL REFERENCES resident(id),
    town_date TEXT NOT NULL,
    time_slot TEXT NOT NULL CHECK (time_slot IN ('MORNING', 'AFTERNOON', 'EVENING', 'NIGHT')),
    action_type TEXT NOT NULL CHECK (action_type IN ('REST', 'WORK', 'TALK', 'EXPLORE', 'HELP')),
    target_id TEXT,
    status TEXT NOT NULL CHECK (status IN ('PLANNED', 'RUNNING', 'COMPLETED', 'FAILED')),
    outcome_json TEXT,
    started_at TEXT,
    completed_at TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (resident_id, town_date, time_slot)
);

CREATE TABLE event_log (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    town_date TEXT NOT NULL,
    resident_ids_json TEXT NOT NULL,
    canonical_facts_json TEXT NOT NULL,
    public_narrative TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE ai_usage (
    id TEXT PRIMARY KEY,
    resident_id TEXT REFERENCES resident(id),
    purpose TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    cached_prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    estimated_cost_cny REAL NOT NULL DEFAULT 0,
    outcome TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE admin_audit_log (
    id TEXT PRIMARY KEY,
    admin_username TEXT NOT NULL,
    action_type TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT,
    reason TEXT NOT NULL,
    before_json TEXT,
    after_json TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX idx_resident_last_active ON resident(last_active_at);
CREATE INDEX idx_daily_goal_town_date ON daily_goal(town_date);
CREATE INDEX idx_resident_action_schedule ON resident_action(town_date, time_slot, status);
CREATE INDEX idx_event_log_town_date ON event_log(town_date);
CREATE INDEX idx_ai_usage_created_at ON ai_usage(created_at);
