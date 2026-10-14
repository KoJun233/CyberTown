--liquibase formatted sql

--changeset cybertown:002
CREATE TABLE resident_presence (
    resident_id TEXT PRIMARY KEY REFERENCES resident(id),
    pos_x REAL NOT NULL CHECK (pos_x >= 0 AND pos_x <= 640),
    pos_y REAL NOT NULL CHECK (pos_y >= 0 AND pos_y <= 360),
    updated_at TEXT NOT NULL
);

CREATE TABLE town_bubble (
    id TEXT PRIMARY KEY,
    resident_id TEXT NOT NULL REFERENCES resident(id),
    message TEXT NOT NULL CHECK (length(message) BETWEEN 1 AND 60),
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL
);

INSERT INTO resident_presence(resident_id, pos_x, pos_y, updated_at)
SELECT id,
       60 + (appearance_seed % 520),
       90 + ((appearance_seed / 7) % 200),
       updated_at
FROM resident;

CREATE INDEX idx_town_bubble_active ON town_bubble(expires_at, created_at);
CREATE INDEX idx_town_bubble_resident_created ON town_bubble(resident_id, created_at);
