BEGIN;

CREATE TABLE conversations
(
    id                  uuid PRIMARY KEY     DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    title               text,
    total_input_tokens  bigint      NOT NULL DEFAULT 0,
    total_output_tokens bigint      NOT NULL DEFAULT 0,
    context_tokens      integer     NOT NULL DEFAULT 0,
    token_limit         integer,
    last_message_at     timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz,
    deleted_at          timestamptz
);

CREATE INDEX idx_conversations_user_recent
    ON conversations (user_id, last_message_at DESC) WHERE deleted_at IS NULL;

COMMIT;