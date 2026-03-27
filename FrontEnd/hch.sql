-- ============================================================
--   EHR BLOCKCHAIN SYSTEM - SCHEMA (POSTGRESQL)
--   Includes: Users, Patients, Hospitals, Admins,
--             Medical Records, Blockchain Transactions,
--             Access Consent, Audit Logs, Appointments
--
--   SEGMENT 1 CHANGES (Schema Fixes on Existing Tables):
--     - users.role CHECK extended to include 'lab' and 'insurer'
--     - users: added is_deleted soft-delete column
--     - users: added updated_at column
--     - patients: blockchain_wallet renamed to fabric_identity,
--                 UNIQUE constraint added, format note updated
--     - patients: added is_deleted soft-delete column
--     - patients: added updated_at column
--     - hospitals: added updated_at column
--     - hospitals: added subscription validity comment for login guard
--     - admins: removed denormalised email column (read via JOIN on users)
--     - admins: added updated_at column
--     - DROP order updated to account for future tables (Segments 2+)
--
--   SEGMENT 2 CHANGES (Five Missing Core Tables):
--     - ADD TABLE: medical_records
--     - ADD TABLE: blockchain_transactions
--     - ADD TABLE: access_consent
--     - ADD TABLE: audit_logs
--     - ADD TABLE: appointments
--
--   SEGMENT 3 CHANGES (Indexes):
--     - Lookup indexes on users(username), users(email)
--     - FK indexes on patients(user_id), hospitals(user_id), admins(user_id)
--     - FK + query indexes on all five new tables
--     - Partial index on audit_logs(patient_id) for patient record queries
--     - Composite index on access_consent(patient_id, status) for consent checks
--     - Composite index on appointments(patient_id, scheduled_at) for scheduling
--
--   SEGMENT 4 CHANGES (Seed Data — Passwords & ID References):
--     - All password_hash values replaced with pgcrypto crypt() bcrypt hashes
--     - All hardcoded integer user_id/patient_id/hospital_id values in INSERT
--       statements replaced with subquery lookups (SELECT … FROM … WHERE …)
--     - Removed all "Segment 4" forward-reference comments; seed data is final
--     - pgcrypto extension declaration confirmed at top of file
--
--   SEGMENT 5 CHANGES (8 Critical Missing Tables):
--     - ADD TABLE: doctors              (individual practitioners per hospital)
--     - ADD TABLE: sessions             (login session tracking + MFA state)
--     - ADD TABLE: otp_events           (MFA codes, brute-force counters)
--     - ADD TABLE: patient_keys         (public key versions for key rotation)
--     - ADD TABLE: key_rewrap_jobs      (background re-encryption job queue)
--     - ADD TABLE: key_escrow           (recovery path for lost patient keys)
--     - ADD TABLE: multi_sig_approvals  (threshold-signing for high-risk ops)
--     - ADD TABLE: emergency_overrides  (break-glass audit trail)
--     - ADD COLUMNS TO: medical_records (parent_record_id, version, amendment_reason)
--     - DROP ORDER updated to include all Segment 5 tables
--     - Indexes added for all Segment 5 tables
--     - Seed data added for doctors + sessions
--
--   SEGMENT 6 CHANGES (8 Important Missing Tables):
--     - ADD TABLE: notifications        (push/email/SMS delivery log)
--     - ADD TABLE: subscription_events  (hospital billing audit trail)
--     - ADD TABLE: consent_policies     (category-scoped consent grants)
--     - ADD TABLE: patient_devices      (registered devices holding private keys)
--     - ADD TABLE: patient_preferences  (default consent + notification settings)
--     - ADD TABLE: dependent_access     (guardian/proxy access for minors)
--     - ADD TABLE: portal_sessions      (patient-portal sessions separate scope)
--     - ADD TABLE: fhir_resource_map    (internal record_id ↔ FHIR Resource.id)
--     - DROP ORDER updated to include all Segment 6 tables
--     - Indexes added for all Segment 6 tables
--     - Seed data added for notifications, patient_preferences, fhir_resource_map
-- ============================================================

-- ============================================================
-- DROP ORDER
-- Must drop dependent tables first (most-dependent → least-dependent).
-- ============================================================
DROP TABLE IF EXISTS fhir_resource_map       CASCADE;
DROP TABLE IF EXISTS portal_sessions         CASCADE;
DROP TABLE IF EXISTS dependent_access        CASCADE;
DROP TABLE IF EXISTS patient_preferences     CASCADE;
DROP TABLE IF EXISTS patient_devices         CASCADE;
DROP TABLE IF EXISTS consent_policies        CASCADE;
DROP TABLE IF EXISTS subscription_events     CASCADE;
DROP TABLE IF EXISTS notifications           CASCADE;
DROP TABLE IF EXISTS multi_sig_approvals     CASCADE;
DROP TABLE IF EXISTS emergency_overrides     CASCADE;
DROP TABLE IF EXISTS key_rewrap_jobs         CASCADE;
DROP TABLE IF EXISTS key_escrow              CASCADE;
DROP TABLE IF EXISTS patient_keys            CASCADE;
DROP TABLE IF EXISTS otp_events              CASCADE;
DROP TABLE IF EXISTS sessions                CASCADE;
DROP TABLE IF EXISTS doctors                 CASCADE;
DROP TABLE IF EXISTS audit_logs              CASCADE;
DROP TABLE IF EXISTS access_consent          CASCADE;
DROP TABLE IF EXISTS blockchain_transactions CASCADE;
DROP TABLE IF EXISTS medical_records         CASCADE;
DROP TABLE IF EXISTS appointments            CASCADE;
DROP TABLE IF EXISTS admins                  CASCADE;
DROP TABLE IF EXISTS hospitals               CASCADE;
DROP TABLE IF EXISTS patients                CASCADE;
DROP TABLE IF EXISTS users                   CASCADE;

-- ============================================================
-- EXTENSION
-- pgcrypto is required for bcrypt password hashing in seed data
-- and for password verification in APP.PY login queries.
-- Enable once per database.
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- USERS TABLE (Central Login System for ALL ROLES)
-- ============================================================
CREATE TABLE users (
    user_id         SERIAL PRIMARY KEY,
    username        VARCHAR(100) UNIQUE NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone_number    VARCHAR(20)  UNIQUE NOT NULL,
    profile_picture VARCHAR(255),
    password_hash   TEXT        NOT NULL,

    -- CHANGED: extended to include 'lab' and 'insurer' per methodology §2.1
    role            VARCHAR(20) NOT NULL
                    CHECK (role IN ('patient', 'hospital', 'admin', 'lab', 'insurer')),

    is_active       BOOLEAN     DEFAULT TRUE,

    -- ADDED: soft-delete for compliance-safe data retention
    is_deleted      BOOLEAN     DEFAULT FALSE,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- ADDED: supports audit trail requirements
    updated_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- PATIENTS TABLE (Patient Profile Info)
-- ============================================================
CREATE TABLE patients (
    patient_id      SERIAL PRIMARY KEY,
    user_id         INT     UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    full_name       VARCHAR(150) NOT NULL,
    date_of_birth   DATE         NOT NULL,
    phone_number    VARCHAR(20)  UNIQUE NOT NULL,
    profile_picture VARCHAR(255),
    address         TEXT         NOT NULL,
    gender          VARCHAR(20),

    -- CHANGED: renamed from blockchain_wallet; stores Hyperledger Fabric
    --          X.509 identity identifier (not an Ethereum 0x address).
    --          UNIQUE constraint added.
    fabric_identity VARCHAR(200) UNIQUE,

    -- ADDED: soft-delete for compliance-safe data retention
    is_deleted      BOOLEAN      DEFAULT FALSE,

    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    -- ADDED: supports audit trail requirements
    updated_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- HOSPITALS TABLE (Hospital Registration Info)
-- ============================================================
CREATE TABLE hospitals (
    hospital_id         SERIAL PRIMARY KEY,
    user_id             INT     UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    hospital_name       VARCHAR(200) NOT NULL,
    license_number      VARCHAR(100) UNIQUE NOT NULL,
    email               VARCHAR(150) NOT NULL,
    phone_number        VARCHAR(20)  UNIQUE NOT NULL,
    profile_picture     VARCHAR(255),
    address             TEXT         NOT NULL,
    subscription_status VARCHAR(20)  DEFAULT 'inactive'
                        CHECK (subscription_status IN ('active', 'inactive')),
    subscription_expiry DATE,

    created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    -- ADDED: supports audit trail requirements
    updated_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP

    -- NOTE (login guard): The APP.PY login query for hospital role MUST
    -- include the following condition to reject expired subscriptions:
    --   WHERE h.subscription_status = 'active'
    --     AND (h.subscription_expiry IS NULL OR h.subscription_expiry >= NOW())
);

-- ============================================================
-- ADMINS TABLE (Admin Profile Info)
-- ============================================================
CREATE TABLE admins (
    admin_id    SERIAL PRIMARY KEY,
    user_id     INT UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    full_name   VARCHAR(150) NOT NULL,
    phone_number    VARCHAR(20)  UNIQUE NOT NULL,
    profile_picture VARCHAR(255),
    -- REMOVED: email column was denormalised (duplicated from users).
    -- To retrieve admin email, JOIN on users.user_id instead:
    --   SELECT u.email FROM admins a JOIN users u ON a.user_id = u.user_id

    admin_level INT DEFAULT 1,  -- 1 = Normal admin, 2 = Super admin

    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- ADDED: supports audit trail requirements
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- MEDICAL RECORDS TABLE
-- Stores encrypted off-chain record references uploaded by hospitals.
-- The actual file lives off-chain (IPFS / file server); only the
-- content-addressed hash and encrypted AES key are stored here.
-- ============================================================
CREATE TABLE medical_records (
    record_id           SERIAL PRIMARY KEY,

    -- Owning patient
    patient_id          INT     NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- Hospital that uploaded the record
    uploaded_by         INT     NOT NULL REFERENCES hospitals(hospital_id) ON DELETE RESTRICT,

    -- Human-readable label (e.g. "Blood Test – Apr 2025")
    record_type         VARCHAR(100) NOT NULL,

    -- Off-chain storage reference (IPFS CID or file-server path)
    file_reference      TEXT    NOT NULL,

    -- AES-256 content-encryption key, itself RSA-wrapped with the
    -- patient's Fabric identity public key
    encrypted_aes_key   TEXT    NOT NULL,

    -- SHA-256 hash of the plaintext file; written on-chain for integrity
    sha256_hash         CHAR(64) NOT NULL,

    record_date         DATE    NOT NULL,
    upload_timestamp    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Soft-delete: record is logically removed but row is retained for
    -- compliance and audit trail purposes
    is_deleted          BOOLEAN   DEFAULT FALSE,

    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- SEGMENT 5: Record versioning — links an amended record back to the
    -- original. NULL for original records; set to the record_id of the
    -- record this row corrects/supersedes for all amendments.
    parent_record_id    INT       REFERENCES medical_records(record_id) ON DELETE SET NULL,

    -- 1 for original records; increments with each amendment.
    version             INT       NOT NULL DEFAULT 1,

    -- Clinical or administrative reason for the amendment (NULL for originals).
    amendment_reason    TEXT
);

-- ============================================================
-- BLOCKCHAIN TRANSACTIONS TABLE
-- Mirrors every on-chain write for off-chain verifiability.
-- One row per Hyperledger Fabric transaction.
-- ============================================================
CREATE TABLE blockchain_transactions (
    tx_id               SERIAL PRIMARY KEY,

    -- The medical record this transaction pertains to
    record_id           INT     NOT NULL REFERENCES medical_records(record_id) ON DELETE RESTRICT,

    -- Hyperledger Fabric transaction hash (globally unique)
    tx_hash             TEXT    UNIQUE NOT NULL,

    -- Block number on the Hyperledger channel where tx was committed
    block_number        BIGINT  NOT NULL,

    -- SHA-256 hash of the record content at the time of the on-chain write
    -- (should match medical_records.sha256_hash for integrity verification)
    sha256_hash         CHAR(64) NOT NULL,

    -- Hyperledger Fabric channel name (e.g. 'hch-channel')
    network             VARCHAR(100) NOT NULL,

    -- Timestamp reported by the Fabric orderer (on-chain time)
    on_chain_timestamp  TIMESTAMP NOT NULL,

    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ACCESS CONSENT TABLE
-- Governs Workflow 2 (Patient grants doctor access to record) and
-- Workflow 3 (Emergency override).  Each row represents one
-- consent request/grant lifecycle.
-- ============================================================
CREATE TABLE access_consent (
    consent_id              SERIAL PRIMARY KEY,

    -- Patient whose record is being requested
    patient_id              INT     NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- Doctor or other entity requesting access (maps to users.user_id)
    requester_id            INT     NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- Role of the requester at the time of the request
    requester_role          VARCHAR(20) NOT NULL
                            CHECK (requester_role IN ('hospital', 'lab', 'insurer')),

    -- Specific record being requested (NULL = request covers all records)
    record_id               INT     REFERENCES medical_records(record_id) ON DELETE SET NULL,

    -- Lifecycle status managed via smart contract
    status                  VARCHAR(10) NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'approved', 'denied', 'revoked')),

    -- Fabric transaction ID of the smart-contract call that set this status
    smart_contract_tx_id    TEXT,

    -- Populated when status transitions to 'approved'
    granted_at              TIMESTAMP,

    -- Optional expiry; NULL means access does not expire automatically
    expires_at              TIMESTAMP,

    -- TRUE for emergency override (Workflow 3); bypasses normal approval flow
    is_emergency            BOOLEAN   DEFAULT FALSE,

    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- AUDIT LOGS TABLE
-- Immutable append-only log of every significant system action.
-- Rows should NEVER be updated or deleted (no updated_at column).
-- The blockchain_proof column anchors each log entry to the chain.
-- ============================================================
CREATE TABLE audit_logs (
    log_id              SERIAL PRIMARY KEY,

    -- User who performed the action
    actor_id            INT     NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- Type of action performed
    action_type         VARCHAR(20) NOT NULL
                        CHECK (action_type IN (
                            'upload',       -- Doctor uploads a medical record
                            'access',       -- Doctor reads a medical record
                            'grant',        -- Patient approves a consent request
                            'revoke',       -- Patient revokes a previously granted consent
                            'deny',         -- Patient denies a consent request
                            'key_release',  -- AES key released to an approved requester
                            'verify'        -- Hash verification check performed on a record
                        )),

    -- Patient whose data is involved (always present)
    patient_id          INT     NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- Specific record involved (NULL for actions not tied to a single record)
    record_id           INT     REFERENCES medical_records(record_id) ON DELETE SET NULL,

    -- Consent entry involved (NULL for upload/verify actions)
    consent_id          INT     REFERENCES access_consent(consent_id) ON DELETE SET NULL,

    -- Fabric transaction hash that anchors this log entry on-chain
    blockchain_proof    TEXT,

    -- IP address of the client that triggered the action
    ip_address          INET,

    logged_at           TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- APPOINTMENTS TABLE
-- Supports the appointments portal page.
-- doctor_id references the hospital user who acts as the doctor.
-- ============================================================
CREATE TABLE appointments (
    appointment_id  SERIAL PRIMARY KEY,

    patient_id      INT     NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- The hospital/doctor account managing this appointment
    doctor_id       INT     NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    scheduled_at    TIMESTAMP NOT NULL,

    status          VARCHAR(15) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),

    notes           TEXT,

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- SEGMENT 5: 8 CRITICAL MISSING TABLES
-- ============================================================

-- ============================================================
-- DOCTORS TABLE
-- Individual practitioners linked to a hospital.
-- Fixes the broken audit trail: every record access is now
-- attributed to a specific doctor, not the shared hospital account.
-- Each doctor gets their own users row (role = 'hospital') so that
-- existing session and permission logic continues to work.
-- ============================================================
CREATE TABLE doctors (
    doctor_id       SERIAL PRIMARY KEY,

    -- Each doctor has their own users row
    user_id         INT         UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- The hospital this doctor is employed by / affiliated with
    hospital_id     INT         NOT NULL REFERENCES hospitals(hospital_id) ON DELETE RESTRICT,

    full_name       VARCHAR(150) NOT NULL,

    -- Medical council license number — unique across the entire platform
    license_number  VARCHAR(100) UNIQUE NOT NULL,

    -- Clinical specialty (Cardiology, Radiology, etc.)
    specialty       VARCHAR(100),

    -- Hyperledger Fabric X.509 identity — needed if doctors sign on-chain
    fabric_identity VARCHAR(200) UNIQUE,

    -- FALSE blocks login without deleting the account
    is_active       BOOLEAN     DEFAULT TRUE,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- SESSIONS TABLE
-- Tracks active login sessions for all portal users.
-- Enforces session expiry and explicit logout / admin revocation.
-- session_id is a UUID so it cannot be brute-forced.
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- already declared above; idempotent

CREATE TABLE sessions (
    session_id      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The authenticated user this session belongs to
    user_id         INT         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- User-agent string for session-management UI
    device_info     TEXT,

    -- IP address at login time
    ip_address      INET,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- Hard expiry — application MUST check this on every authenticated request
    expires_at      TIMESTAMP   NOT NULL,

    -- Explicit logout or admin force-revoke sets this TRUE
    revoked         BOOLEAN     DEFAULT FALSE,

    -- TRUE once the user has completed MFA in this session
    mfa_verified    BOOLEAN     DEFAULT FALSE
);

-- ============================================================
-- OTP_EVENTS TABLE
-- Records every one-time-password / MFA event:
-- code generation, successful verifications, and failures.
-- Used for brute-force detection (failed_attempts counter) and
-- compliance logging of authentication events.
-- ============================================================
CREATE TABLE otp_events (
    otp_id          SERIAL PRIMARY KEY,

    user_id         INT         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- 'login_mfa' | 'password_reset' | 'device_verify' | 'consent_confirm'
    purpose         VARCHAR(30) NOT NULL
                    CHECK (purpose IN ('login_mfa', 'password_reset', 'device_verify', 'consent_confirm')),

    -- Bcrypt hash of the OTP code (never store plain OTPs)
    code_hash       TEXT        NOT NULL,

    -- Delivery channel used for this code
    channel         VARCHAR(10) NOT NULL
                    CHECK (channel IN ('sms', 'email', 'totp')),

    -- Code validity window
    expires_at      TIMESTAMP   NOT NULL,

    -- Outcome of this code event
    -- 'pending' until verified or expired; 'used' on successful verify;
    -- 'expired' or 'failed' on exhaustion / time-out
    status          VARCHAR(10) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'used', 'expired', 'failed')),

    -- Incremented on each wrong-code attempt for this event row
    failed_attempts INT         DEFAULT 0,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    verified_at     TIMESTAMP
);

-- ============================================================
-- PATIENT_KEYS TABLE
-- Stores every public key version a patient has ever registered.
-- Enables key rotation: when a patient registers a new key, the old
-- row is revoked (revoked_at set) and key_rewrap_jobs is populated
-- to re-wrap every historical encrypted_aes_key.
-- Only one key per patient should have is_active = TRUE at any time
-- (enforced by the application layer).
-- ============================================================
CREATE TABLE patient_keys (
    key_id              SERIAL PRIMARY KEY,

    patient_id          INT         NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- RSA or EC public key in PEM format
    public_key_pem      TEXT        NOT NULL,

    -- SHA-256 fingerprint of the public key for quick lookups and de-dup
    key_fingerprint     VARCHAR(128) UNIQUE NOT NULL,

    -- TRUE for the patient's current active key; FALSE for historical keys
    is_active           BOOLEAN     DEFAULT TRUE,

    -- When this key became the active key
    activated_at        TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- Populated when this key is superseded or explicitly revoked
    revoked_at          TIMESTAMP,

    created_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- KEY_REWRAP_JOBS TABLE
-- Background job queue for re-wrapping encrypted_aes_key values
-- when a patient rotates their key pair. One row per
-- (patient, record) pair per rotation event.
-- A background worker processes 'pending' rows, updates
-- medical_records.encrypted_aes_key, then marks the row 'completed'.
-- ============================================================
CREATE TABLE key_rewrap_jobs (
    job_id          SERIAL PRIMARY KEY,

    -- Patient whose records need re-wrapping
    patient_id      INT         NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- The superseded key (the one that currently wraps the AES key)
    old_key_id      INT         NOT NULL REFERENCES patient_keys(key_id) ON DELETE RESTRICT,

    -- The new active key (the one to re-wrap with)
    new_key_id      INT         NOT NULL REFERENCES patient_keys(key_id) ON DELETE RESTRICT,

    -- The specific medical record being re-wrapped in this job step
    record_id       INT         NOT NULL REFERENCES medical_records(record_id) ON DELETE RESTRICT,

    -- Job lifecycle
    status          VARCHAR(10) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'completed', 'failed')),

    -- Retry counter — worker stops after a configured maximum
    attempts        INT         DEFAULT 0,

    -- Last error message if status = 'failed'
    error_message   TEXT,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    completed_at    TIMESTAMP
);

-- ============================================================
-- KEY_ESCROW TABLE
-- Recovery path for patients who lose their private key.
-- The escrow fragment is encrypted with the platform's HSM key
-- and can only be reconstructed via a multi-party approval process
-- (see multi_sig_approvals).  Storing an escrow record is optional
-- per patient — some may opt out.
-- ============================================================
CREATE TABLE key_escrow (
    escrow_id           SERIAL PRIMARY KEY,

    patient_id          INT         UNIQUE NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- The key this escrow record covers
    key_id              INT         NOT NULL REFERENCES patient_keys(key_id) ON DELETE RESTRICT,

    -- Encrypted escrow fragment (HSM-wrapped, never plaintext)
    encrypted_fragment  TEXT        NOT NULL,

    -- Identifier of the HSM key / wrapping key version used
    hsm_key_reference   VARCHAR(200) NOT NULL,

    -- 'active' = usable for recovery; 'used' = already consumed;
    -- 'revoked' = invalidated (e.g. on key rotation)
    status              VARCHAR(10) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'used', 'revoked')),

    created_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MULTI_SIG_APPROVALS TABLE
-- Threshold-signing record for high-risk operations:
-- emergency record access, key escrow recovery, admin-level
-- consent overrides.  One row per approver per operation.
-- The application collects rows until the required threshold
-- (e.g. 2-of-3) is met, then proceeds with the operation.
-- ============================================================
CREATE TABLE multi_sig_approvals (
    approval_id     SERIAL PRIMARY KEY,

    -- Identifies which high-risk operation this row approves
    -- 'emergency_override' | 'key_recovery' | 'admin_override'
    operation_type  VARCHAR(25) NOT NULL
                    CHECK (operation_type IN ('emergency_override', 'key_recovery', 'admin_override')),

    -- Polymorphic reference: the ID of the row in the relevant table
    -- (emergency_overrides.override_id, key_escrow.escrow_id, etc.)
    reference_id    INT         NOT NULL,

    -- The approver (senior doctor, admin, compliance officer)
    approver_id     INT         NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- Cryptographic signature over (operation_type || reference_id || approver_id || approved_at)
    -- using the approver's Fabric identity key
    signature       TEXT        NOT NULL,

    -- Fabric transaction hash that recorded this approval on-chain
    fabric_tx_hash  TEXT,

    approved_at     TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- EMERGENCY_OVERRIDES TABLE
-- Structured break-glass audit trail beyond the boolean
-- is_emergency flag in access_consent.  Every emergency
-- access must have a corresponding row here with a clinical
-- justification, a time-limited access window, and a post-access
-- compliance review outcome.
-- Satisfies HIPAA §164.312(b) and GDPR Art. 9(2)(c) audit
-- requirements for emergency processing of health data.
-- ============================================================
CREATE TABLE emergency_overrides (
    override_id         SERIAL PRIMARY KEY,

    -- The access_consent row that triggered the override
    consent_id          INT         NOT NULL REFERENCES access_consent(consent_id) ON DELETE RESTRICT,

    -- Practitioner who invoked break-glass
    triggered_by        INT         NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- Second approver (senior doctor or admin).
    -- NULL if the system operates a single-approver model.
    authorised_by       INT         REFERENCES users(user_id) ON DELETE SET NULL,

    -- Mandatory clinical reason for the override — free text
    justification       TEXT        NOT NULL,

    -- Time-limited access grant expiry.  Access must lapse after this timestamp.
    access_window_end   TIMESTAMP   NOT NULL,

    -- Compliance officer who reviewed this override post-access
    reviewed_by         INT         REFERENCES users(user_id) ON DELETE SET NULL,

    -- When the post-access compliance review was completed
    reviewed_at         TIMESTAMP,

    -- 'justified' | 'unjustified' | 'under_review'
    -- NULL until reviewed_by is populated
    review_outcome      VARCHAR(15)
                        CHECK (review_outcome IN ('justified', 'unjustified', 'under_review')),

    created_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);
-- Created after all tables so that the index definitions are
-- readable in one place and do not clutter the CREATE TABLE blocks.
-- UNIQUE indexes that duplicate constraints already declared inline
-- (e.g. users.username, users.email, patients.fabric_identity,
-- blockchain_transactions.tx_hash) are intentionally omitted here —
-- PostgreSQL creates those index structures automatically.
-- ============================================================

-- ------------------------------------------------------------
-- USERS
-- ------------------------------------------------------------
-- username and email are already UNIQUE (implicit B-tree index).
-- The explicit named indexes below make query plans readable and
-- allow the DBA to REINDEX them individually.
CREATE INDEX idx_users_username   ON users (username);
CREATE INDEX idx_users_email      ON users (email);
CREATE INDEX idx_users_role       ON users (role);
-- Filters out soft-deleted rows efficiently in application queries
CREATE INDEX idx_users_active     ON users (is_deleted, is_active);

-- ------------------------------------------------------------
-- PATIENTS
-- ------------------------------------------------------------
-- FK lookup: join patients → users
CREATE INDEX idx_patients_user_id       ON patients (user_id);
-- Consent + audit queries filter by patient_id heavily
CREATE INDEX idx_patients_is_deleted    ON patients (is_deleted);

-- ------------------------------------------------------------
-- HOSPITALS
-- ------------------------------------------------------------
CREATE INDEX idx_hospitals_user_id      ON hospitals (user_id);
-- Subscription status checked on every hospital login
CREATE INDEX idx_hospitals_subscription ON hospitals (subscription_status, subscription_expiry);

-- ------------------------------------------------------------
-- ADMINS
-- ------------------------------------------------------------
CREATE INDEX idx_admins_user_id         ON admins (user_id);

-- ------------------------------------------------------------
-- MEDICAL RECORDS
-- ------------------------------------------------------------
-- Most common query: all records for a given patient
CREATE INDEX idx_mr_patient_id          ON medical_records (patient_id);
-- Hospital dashboard: all records uploaded by a hospital
CREATE INDEX idx_mr_uploaded_by         ON medical_records (uploaded_by);
-- Exclude soft-deleted records from all application queries
CREATE INDEX idx_mr_is_deleted          ON medical_records (is_deleted);
-- Date-range queries (e.g. records from the last 6 months)
CREATE INDEX idx_mr_record_date         ON medical_records (record_date);

-- ------------------------------------------------------------
-- BLOCKCHAIN TRANSACTIONS
-- ------------------------------------------------------------
-- tx_hash is already UNIQUE (implicit B-tree index).
-- FK lookup: all transactions for a given record
CREATE INDEX idx_bctx_record_id         ON blockchain_transactions (record_id);
-- Block explorer / ordering queries
CREATE INDEX idx_bctx_block_number      ON blockchain_transactions (block_number);
-- On-chain timestamp range queries
CREATE INDEX idx_bctx_on_chain_ts       ON blockchain_transactions (on_chain_timestamp);

-- ------------------------------------------------------------
-- ACCESS CONSENT
-- ------------------------------------------------------------
-- Most common query: all consent requests for a patient
CREATE INDEX idx_ac_patient_id          ON access_consent (patient_id);
-- Doctor/hospital dashboard: all requests made by a requester
CREATE INDEX idx_ac_requester_id        ON access_consent (requester_id);
-- FK: consent entries linked to a specific record
CREATE INDEX idx_ac_record_id           ON access_consent (record_id);
-- Composite: patient consent dashboard filtered by status
-- (e.g. "show all pending requests for this patient")
CREATE INDEX idx_ac_patient_status      ON access_consent (patient_id, status);
-- Smart-contract callback lookup: find consent row by tx_id
CREATE INDEX idx_ac_sc_tx_id            ON access_consent (smart_contract_tx_id);

-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------
-- Audit logs are append-only and queried by patient or actor.
-- actor_id: "show all actions taken by this user"
CREATE INDEX idx_al_actor_id            ON audit_logs (actor_id);
-- patient_id: "show all events involving this patient's data"
CREATE INDEX idx_al_patient_id          ON audit_logs (patient_id);
-- record_id: "show all events for this specific record"
CREATE INDEX idx_al_record_id           ON audit_logs (record_id);
-- consent_id: "show all events tied to this consent request"
CREATE INDEX idx_al_consent_id          ON audit_logs (consent_id);
-- Time-range queries for compliance reports
CREATE INDEX idx_al_logged_at           ON audit_logs (logged_at);
-- Action-type filter (e.g. all 'access' events in a date range)
CREATE INDEX idx_al_action_type         ON audit_logs (action_type, logged_at);

-- ------------------------------------------------------------
-- APPOINTMENTS
-- ------------------------------------------------------------
-- Patient portal: upcoming appointments for a patient
CREATE INDEX idx_appt_patient_id        ON appointments (patient_id);
-- Doctor/hospital dashboard: appointments managed by a doctor
CREATE INDEX idx_appt_doctor_id         ON appointments (doctor_id);
-- Status filter (e.g. all pending appointments)
CREATE INDEX idx_appt_status            ON appointments (status);
-- Composite: patient schedule ordered by time
-- (covers the most common portal query in one index scan)
CREATE INDEX idx_appt_patient_schedule  ON appointments (patient_id, scheduled_at);

-- ------------------------------------------------------------
-- SEGMENT 5: INDEXES FOR CRITICAL MISSING TABLES
-- ------------------------------------------------------------

-- DOCTORS
-- FK from doctors → hospitals (most common join direction)
CREATE INDEX idx_doctors_hospital_id    ON doctors (hospital_id);
-- FK from doctors → users
CREATE UNIQUE INDEX idx_doctors_user_id ON doctors (user_id);
-- License lookup — already UNIQUE (implicit B-tree); explicit for readability
CREATE UNIQUE INDEX idx_doctors_license ON doctors (license_number);
-- Active-doctor filter for portal queries
CREATE INDEX idx_doctors_is_active      ON doctors (is_active);

-- SESSIONS
-- Most common query: all sessions for a given user
CREATE INDEX idx_sess_user_id           ON sessions (user_id);
-- Expiry cleanup job: find expired sessions efficiently
CREATE INDEX idx_sess_expires_at        ON sessions (expires_at);
-- Active-session lookups: partial index on non-revoked, non-expired rows
CREATE INDEX idx_sess_active            ON sessions (user_id, revoked) WHERE revoked = FALSE;

-- OTP_EVENTS
-- Per-user OTP lookup (find pending codes for a user + purpose)
CREATE INDEX idx_otp_user_purpose       ON otp_events (user_id, purpose, status);
-- Expiry cleanup job
CREATE INDEX idx_otp_expires_at         ON otp_events (expires_at);

-- PATIENT_KEYS
-- All keys for a given patient (key history)
CREATE INDEX idx_pk_patient_id          ON patient_keys (patient_id);
-- Fingerprint lookup — already UNIQUE (implicit B-tree); explicit for readability
CREATE UNIQUE INDEX idx_pk_fingerprint  ON patient_keys (key_fingerprint);
-- Active-key fast path: partial index returns the one current key per patient
CREATE INDEX idx_pk_active              ON patient_keys (patient_id) WHERE is_active = TRUE;

-- KEY_REWRAP_JOBS
-- Worker queue: all pending jobs (most important query for the background worker)
CREATE INDEX idx_krj_patient_pending    ON key_rewrap_jobs (patient_id, status) WHERE status = 'pending';
-- All jobs for a given record (used when a record is deleted / soft-deleted)
CREATE INDEX idx_krj_record_id          ON key_rewrap_jobs (record_id);
-- All jobs referencing a specific key version
CREATE INDEX idx_krj_old_key_id         ON key_rewrap_jobs (old_key_id);
CREATE INDEX idx_krj_new_key_id         ON key_rewrap_jobs (new_key_id);

-- KEY_ESCROW
-- patient_id is already UNIQUE (implicit B-tree); explicit for readability
CREATE UNIQUE INDEX idx_esc_patient_id  ON key_escrow (patient_id);
-- Key reference lookup
CREATE INDEX idx_esc_key_id             ON key_escrow (key_id);

-- MULTI_SIG_APPROVALS
-- Find all approvals for a given operation
CREATE INDEX idx_msa_operation          ON multi_sig_approvals (operation_type, reference_id);
-- Per-approver view (show all approvals by a user)
CREATE INDEX idx_msa_approver_id        ON multi_sig_approvals (approver_id);

-- EMERGENCY_OVERRIDES
-- FK to access_consent
CREATE INDEX idx_eo_consent_id          ON emergency_overrides (consent_id);
-- Who triggered the override
CREATE INDEX idx_eo_triggered_by        ON emergency_overrides (triggered_by);
-- Compliance dashboard: overrides pending review (reviewed_at IS NULL)
CREATE INDEX idx_eo_pending_review      ON emergency_overrides (reviewed_at) WHERE reviewed_at IS NULL;
-- Review-outcome filter for compliance reports
CREATE INDEX idx_eo_review_outcome      ON emergency_overrides (review_outcome);

-- MEDICAL_RECORDS — additional index for versioning queries
-- Find all amendments of a given original record
CREATE INDEX idx_mr_parent_record_id    ON medical_records (parent_record_id) WHERE parent_record_id IS NOT NULL;


-- ============================================================
-- SEED DATA
--
-- SECURITY: All passwords are hashed with bcrypt (cost factor 12)
-- via pgcrypto's crypt() function.  The plaintext passwords used
-- here are development-only defaults; they MUST be rotated before
-- any deployment to a non-local environment.
--
-- ID SAFETY: No hardcoded integer IDs appear anywhere in this
-- section.  Every foreign-key value is resolved via a subquery
-- lookup on a stable unique key (username, license_number, etc.)
-- so that re-seeding on a fresh database always produces correct
-- references regardless of SERIAL sequence state.
--
-- APP.PY PASSWORD VERIFICATION:
--   Use pgcrypto's crypt() for login checks:
--     SELECT user_id FROM users
--     WHERE username = $1
--       AND password_hash = crypt($2, password_hash);
-- ============================================================

-- ============================================================
-- USERS — ADMINS
-- ============================================================
INSERT INTO users (username, email, phone_number, password_hash, role)
VALUES
(
    'emmanuel',
    'emmanuel@gmail.com',
    '+91-9000000001',
    crypt('Emma432', gen_salt('bf', 12)),
    'admin'
),
(
    'jimmy',
    'jimmy@gmail.com',
    '+91-9000000002',
    crypt('Jimm432', gen_salt('bf', 12)),
    'admin'
),
(
    'william',
    'william@gmail.com',
    '+91-9000000003',
    crypt('Will432', gen_salt('bf', 12)),
    'admin'
),
(
    'khamis',
    'khamis@gmail.com',
    '+91-9000000004',
    crypt('Kham432', gen_salt('bf', 12)),
    'admin'
);

-- ============================================================
-- ADMINS — profile rows linked to users above
-- ============================================================
INSERT INTO admins (user_id, full_name, phone_number, admin_level)
VALUES
(
    (SELECT user_id FROM users WHERE username = 'emmanuel'),
    'Emmanuel',
    '+91-9000000001',
    2   -- Super admin
),
(
    (SELECT user_id FROM users WHERE username = 'jimmy'),
    'Jimmy',
    '+91-9000000002',
    1
),
(
    (SELECT user_id FROM users WHERE username = 'william'),
    'William',
    '+91-9000000003',
    1
),
(
    (SELECT user_id FROM users WHERE username = 'khamis'),
    'Khamis',
    '+91-9000000004',
    1
);

-- ============================================================
-- USERS — HOSPITALS
-- ============================================================
INSERT INTO users (username, email, phone_number, password_hash, role)
VALUES
(
    'citycare',
    'citycare@example.com',
    '+91-9823456711',
    crypt('Hosp123', gen_salt('bf', 12)),
    'hospital'
),
(
    'sunrise',
    'sunrise@example.com',
    '+91-9988776612',
    crypt('Sun789', gen_salt('bf', 12)),
    'hospital'
),
(
    'central',
    'central@example.com',
    '+91-7788994411',
    crypt('Cent456', gen_salt('bf', 12)),
    'hospital'
);

-- ============================================================
-- HOSPITALS — profile rows linked to users above
-- ============================================================
INSERT INTO hospitals (user_id, hospital_name, license_number, email, phone_number, address, subscription_status, subscription_expiry)
VALUES
(
    (SELECT user_id FROM users WHERE username = 'citycare'),
    'City Care Hospital',
    'LIC-H001',
    'citycare@example.com',
    '+91-9823456711',
    'Plot 12, Green Avenue, Delhi',
    'active',
    '2026-12-31'
),
(
    (SELECT user_id FROM users WHERE username = 'sunrise'),
    'Sunrise Medical Center',
    'LIC-H002',
    'sunrise@example.com',
    '+91-9988776612',
    '45 MG Road, Bengaluru',
    'inactive',
    NULL
),
(
    (SELECT user_id FROM users WHERE username = 'central'),
    'Central Health Clinic',
    'LIC-H003',
    'central@example.com',
    '+91-7788994411',
    '89 Park Street, Kolkata',
    'active',
    '2026-08-15'
);

-- ============================================================
-- USERS — PATIENTS
-- ============================================================
INSERT INTO users (username, email, phone_number, password_hash, role)
VALUES
(
    'rohan',
    'rohan@example.com',
    '+91-9001234567',
    crypt('Rohan12', gen_salt('bf', 12)),
    'patient'
),
(
    'amina',
    'amina@example.com',
    '+91-8887654321',
    crypt('Amina34', gen_salt('bf', 12)),
    'patient'
),
(
    'joseph',
    'joseph@example.com',
    '+91-9123456789',
    crypt('Jose56', gen_salt('bf', 12)),
    'patient'
);

-- ============================================================
-- PATIENTS — profile rows linked to users above
-- ============================================================
INSERT INTO patients (user_id, full_name, date_of_birth, phone_number, address, gender, fabric_identity)
VALUES
(
    (SELECT user_id FROM users WHERE username = 'rohan'),
    'Rohan Sharma',
    '1998-04-12',
    '+91-9001234567',
    'Sector 22, Chandigarh',
    'Male',
    'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'
),
(
    (SELECT user_id FROM users WHERE username = 'amina'),
    'Amina Rahman',
    '2000-09-30',
    '+91-8887654321',
    'Old City, Hyderabad',
    'Female',
    'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'
),
(
    (SELECT user_id FROM users WHERE username = 'joseph'),
    'Joseph Daniel',
    '1995-01-15',
    '+91-9123456789',
    'Marine Drive, Mumbai',
    'Male',
    'CN=joseph.daniel@hch,OU=patient,O=HCH,C=IN'
);

-- ============================================================
-- MEDICAL RECORDS — one per patient, uploaded by City Care
-- ============================================================
INSERT INTO medical_records (patient_id, uploaded_by, record_type, file_reference, encrypted_aes_key, sha256_hash, record_date)
VALUES
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'Blood Test Report',
    'ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco',
    'RSA_WRAP::PLACEHOLDER_KEY_ROHAN_001',
    'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2',
    '2025-11-10'
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'X-Ray Report',
    'ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG',
    'RSA_WRAP::PLACEHOLDER_KEY_AMINA_001',
    'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5',
    '2025-12-03'
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=joseph.daniel@hch,OU=patient,O=HCH,C=IN'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'Discharge Summary',
    'ipfs://QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx',
    'RSA_WRAP::PLACEHOLDER_KEY_JOSEPH_001',
    'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
    '2026-01-22'
);

-- ============================================================
-- BLOCKCHAIN TRANSACTIONS — one per medical record above
-- ============================================================
INSERT INTO blockchain_transactions (record_id, tx_hash, block_number, sha256_hash, network, on_chain_timestamp)
VALUES
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2'),
    'fab1tx_a3f1e2b4_rohan_bloodtest_001',
    1042,
    'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2',
    'hch-channel',
    '2025-11-10 14:32:00'
),
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    'fab1tx_b4c5d6e7_amina_xray_001',
    1087,
    'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5',
    'hch-channel',
    '2025-12-03 09:15:00'
),
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'),
    'fab1tx_c5d6e7f8_joseph_discharge_001',
    1134,
    'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
    'hch-channel',
    '2026-01-22 17:05:00'
);

-- ============================================================
-- ACCESS CONSENT
--   Row 1: Sunrise requests access to Rohan's blood test (pending)
--   Row 2: City Care approved to access Amina's X-ray
-- ============================================================
INSERT INTO access_consent (patient_id, requester_id, requester_role, record_id, status, smart_contract_tx_id, granted_at, expires_at, is_emergency)
VALUES
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'),
    (SELECT user_id    FROM users    WHERE username = 'sunrise'),
    'hospital',
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2'),
    'pending',
    NULL,
    NULL,
    NULL,
    FALSE
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    'hospital',
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    'approved',
    'fab1tx_consent_amina_xray_citycare',
    '2026-01-05 10:00:00',
    '2026-07-05 10:00:00',
    FALSE
);

-- ============================================================
-- AUDIT LOGS — upload events for each record + one access event
-- ============================================================
INSERT INTO audit_logs (actor_id, action_type, patient_id, record_id, consent_id, blockchain_proof, ip_address)
VALUES
(
    -- City Care uploads Rohan's blood test
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    'upload',
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'),
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2'),
    NULL,
    'fab1tx_a3f1e2b4_rohan_bloodtest_001',
    '10.0.0.5'
),
(
    -- City Care uploads Amina's X-ray
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    'upload',
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    NULL,
    'fab1tx_b4c5d6e7_amina_xray_001',
    '10.0.0.5'
),
(
    -- City Care uploads Joseph's discharge summary
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    'upload',
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=joseph.daniel@hch,OU=patient,O=HCH,C=IN'),
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'),
    NULL,
    'fab1tx_c5d6e7f8_joseph_discharge_001',
    '10.0.0.5'
),
(
    -- City Care accesses Amina's X-ray under approved consent
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    'access',
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    (SELECT record_id  FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    (SELECT consent_id FROM access_consent   WHERE smart_contract_tx_id = 'fab1tx_consent_amina_xray_citycare'),
    'fab1tx_consent_amina_xray_citycare',
    '10.0.0.5'
);

-- ============================================================
-- APPOINTMENTS — one per patient, managed by City Care
-- ============================================================
INSERT INTO appointments (patient_id, doctor_id, scheduled_at, status, notes)
VALUES
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'),
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    '2026-04-10 10:00:00',
    'confirmed',
    'Follow-up for blood test results'
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    '2026-04-14 11:30:00',
    'pending',
    'Initial consultation'
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=joseph.daniel@hch,OU=patient,O=HCH,C=IN'),
    (SELECT user_id    FROM users    WHERE username = 'citycare'),
    '2026-04-18 09:00:00',
    'confirmed',
    'Post-discharge check-up'
);

-- ============================================================
-- SEGMENT 5 SEED DATA
-- ============================================================

-- ============================================================
-- USERS — DOCTORS
-- Each doctor gets their own users row (role = 'hospital') so that
-- the existing session and role-check logic works without changes.
-- ============================================================
INSERT INTO users (username, email, phone_number, password_hash, role)
VALUES
(
    'dr_kapoor',
    'dr.kapoor@citycare.example.com',
    '+91-9100000001',
    crypt('DrKap12', gen_salt('bf', 12)),
    'hospital'
),
(
    'dr_mehta',
    'dr.mehta@citycare.example.com',
    '+91-9100000002',
    crypt('DrMeh34', gen_salt('bf', 12)),
    'hospital'
),
(
    'dr_iyer',
    'dr.iyer@central.example.com',
    '+91-9100000003',
    crypt('DrIye56', gen_salt('bf', 12)),
    'hospital'
);

-- ============================================================
-- DOCTORS — profile rows linked to users above
-- ============================================================
INSERT INTO doctors (user_id, hospital_id, full_name, license_number, specialty, fabric_identity)
VALUES
(
    (SELECT user_id     FROM users     WHERE username = 'dr_kapoor'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'Dr. Anita Kapoor',
    'MED-D001',
    'Cardiology',
    'CN=dr.kapoor@hch,OU=doctor,O=HCH,C=IN'
),
(
    (SELECT user_id     FROM users     WHERE username = 'dr_mehta'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'Dr. Rahul Mehta',
    'MED-D002',
    'Radiology',
    'CN=dr.mehta@hch,OU=doctor,O=HCH,C=IN'
),
(
    (SELECT user_id     FROM users     WHERE username = 'dr_iyer'),
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H003'),
    'Dr. Priya Iyer',
    'MED-D003',
    'General Medicine',
    'CN=dr.iyer@hch,OU=doctor,O=HCH,C=IN'
);

-- ============================================================
-- SESSIONS — one active session per doctor (dev/demo data).
-- expires_at is set 8 hours from now via CURRENT_TIMESTAMP.
-- In production, session tokens are generated server-side;
-- these rows are for development reference only.
-- ============================================================
INSERT INTO sessions (user_id, device_info, ip_address, expires_at, revoked, mfa_verified)
VALUES
(
    (SELECT user_id FROM users WHERE username = 'dr_kapoor'),
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    '10.0.1.20',
    CURRENT_TIMESTAMP + INTERVAL '8 hours',
    FALSE,
    TRUE
),
(
    (SELECT user_id FROM users WHERE username = 'dr_mehta'),
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    '10.0.1.21',
    CURRENT_TIMESTAMP + INTERVAL '8 hours',
    FALSE,
    TRUE
),
(
    (SELECT user_id FROM users WHERE username = 'dr_iyer'),
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1',
    '10.0.2.15',
    CURRENT_TIMESTAMP + INTERVAL '8 hours',
    FALSE,
    FALSE   -- MFA not yet completed in this session
);


-- ============================================================
-- SEGMENT 6: 8 IMPORTANT MISSING TABLES
-- ============================================================

-- ============================================================
-- NOTIFICATIONS TABLE
-- Delivery log for every push / email / SMS event triggered by
-- the system (consent requests, access alerts, record uploads,
-- subscription renewals, etc.).  One row per delivery attempt.
-- read_at NULL means the notification has not been opened yet;
-- delivered_at NULL means delivery has not been confirmed.
-- ============================================================
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,

    -- The user this notification is addressed to
    recipient_id    INT         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    -- What triggered this notification
    type            VARCHAR(30) NOT NULL
                    CHECK (type IN (
                        'consent_request',      -- A new access-consent row arrived
                        'access_granted',       -- Patient approved a consent request
                        'access_denied',        -- Patient denied a consent request
                        'access_revoked',       -- Patient revoked a previously granted consent
                        'record_uploaded',      -- A new medical record was uploaded
                        'appointment_reminder', -- Upcoming appointment alert
                        'key_rotation',         -- Patient's key rotation completed
                        'subscription_expiry',  -- Hospital subscription nearing expiry
                        'emergency_override'    -- Break-glass access was invoked
                    )),

    -- Delivery channel used for this notification
    channel         VARCHAR(10) NOT NULL
                    CHECK (channel IN ('in_app', 'email', 'sms', 'push')),

    -- Polymorphic FK: the ID of the triggering row
    -- (consent_id, record_id, appointment_id, override_id, etc.)
    reference_id    INT,

    -- Short message text (or template key for i18n systems)
    message         TEXT        NOT NULL,

    -- NULL until delivery is confirmed by the channel provider
    delivered_at    TIMESTAMP,

    -- NULL until the user opens / acknowledges the notification
    read_at         TIMESTAMP,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- SUBSCRIPTION_EVENTS TABLE
-- Append-only billing audit trail for hospital subscriptions.
-- One row per billing lifecycle event: activation, renewal,
-- expiry, cancellation, or plan change.  Provides the history
-- that the hospitals table (which stores only current state)
-- cannot supply on its own.
-- ============================================================
CREATE TABLE subscription_events (
    event_id            SERIAL PRIMARY KEY,

    hospital_id         INT         NOT NULL REFERENCES hospitals(hospital_id) ON DELETE RESTRICT,

    -- Type of billing event
    event_type          VARCHAR(15) NOT NULL
                        CHECK (event_type IN (
                            'activated',    -- Subscription first activated
                            'renewed',      -- Subscription renewed for another cycle
                            'expired',      -- Subscription lapsed at end of term
                            'cancelled',    -- Subscription cancelled before expiry
                            'plan_changed'  -- Plan tier or pricing changed
                        )),

    -- Human-readable plan name (e.g. 'Basic', 'Pro', 'Enterprise')
    plan_name           VARCHAR(100),

    -- Billing amount for this event (NULL for non-payment events)
    amount              NUMERIC(12, 2),

    -- ISO 4217 currency code (e.g. 'INR', 'USD')
    currency            CHAR(3),

    -- Provider invoice or receipt reference (Stripe charge_id, Razorpay order_id, etc.)
    invoice_reference   VARCHAR(200),

    -- Validity window this event covers
    valid_from          DATE,
    valid_to            DATE,

    created_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- CONSENT_POLICIES TABLE
-- Category-level consent grants so patients can approve access
-- to "all cardiology records" or "all records from 2025"
-- without granting everything.  A consent_policy row acts as a
-- standing rule; access_consent rows can reference a policy_id
-- instead of (or in addition to) a specific record_id.
-- ============================================================
CREATE TABLE consent_policies (
    policy_id       SERIAL PRIMARY KEY,

    -- Patient whose records this policy covers
    patient_id      INT         NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- Entity being granted standing access
    grantee_id      INT         NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- Optional: limit to a specific record_type string
    -- (e.g. 'Lab Report', 'X-Ray Report').  NULL = all types.
    record_type     VARCHAR(100),

    -- Optional: only records uploaded by a specific hospital
    hospital_id     INT         REFERENCES hospitals(hospital_id) ON DELETE SET NULL,

    -- Optional date range filter on medical_records.record_date
    -- NULL bounds mean open-ended (from beginning / to end of time)
    date_from       DATE,
    date_to         DATE,

    -- Lifecycle status of this standing policy
    status          VARCHAR(10) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'revoked', 'expired')),

    -- Fabric transaction ID that last updated this policy's status
    smart_contract_tx_id TEXT,

    -- When this policy was granted / activated
    granted_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- NULL = no expiry; set to enforce time-limited standing grants
    expires_at      TIMESTAMP,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- PATIENT_DEVICES TABLE
-- Registry of devices that hold a patient's private key
-- (phone, browser, hardware token).  Required so that when a
-- device is lost or stolen the system can trigger targeted key
-- revocation and queue key_rewrap_jobs for affected records.
-- ============================================================
CREATE TABLE patient_devices (
    device_id           SERIAL PRIMARY KEY,

    patient_id          INT         NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,

    -- Human-readable label set by the patient (e.g. "My iPhone 15")
    device_name         VARCHAR(200) NOT NULL,

    -- Cryptographic fingerprint of the device's signing key or
    -- platform attestation certificate (e.g. Android Keystore key ID)
    device_fingerprint  VARCHAR(256) NOT NULL,

    -- Platform that generated the key material
    platform            VARCHAR(10) NOT NULL
                        CHECK (platform IN ('ios', 'android', 'web', 'hardware')),

    registered_at       TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- Populated when the device is reported lost/stolen or replaced
    revoked_at          TIMESTAMP
);

-- ============================================================
-- PATIENT_PREFERENCES TABLE
-- Per-patient portal settings: default consent behaviour,
-- preferred notification channel, language, and timezone.
-- One row per patient (UNIQUE on patient_id).
-- ============================================================
CREATE TABLE patient_preferences (
    preference_id               SERIAL PRIMARY KEY,

    patient_id                  INT         UNIQUE NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,

    -- Auto-approve consent requests from the patient's own hospital(s)
    -- without requiring manual review each time
    auto_approve_same_hospital  BOOLEAN     DEFAULT FALSE,

    -- Preferred channel for notification delivery
    notification_channel        VARCHAR(10) DEFAULT 'in_app'
                                CHECK (notification_channel IN ('in_app', 'email', 'sms', 'both')),

    -- BCP-47 language tag (e.g. 'en', 'hi', 'te')
    language                    VARCHAR(10) DEFAULT 'en',

    -- IANA timezone string (e.g. 'Asia/Kolkata')
    timezone                    VARCHAR(60) DEFAULT 'Asia/Kolkata',

    -- Whether the patient has opted in to anonymous analytics
    analytics_opt_in            BOOLEAN     DEFAULT FALSE,

    created_at                  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- DEPENDENT_ACCESS TABLE
-- Formal delegation mechanism for a parent managing a minor
-- child's records, or a legal guardian managing an incapacitated
-- adult's records.  An admin must verify the guardianship
-- document before the row is activated.
-- ============================================================
CREATE TABLE dependent_access (
    delegation_id           SERIAL PRIMARY KEY,

    -- The user who is acting as guardian / proxy
    guardian_id             INT         NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,

    -- The patient whose records are being managed
    patient_id              INT         NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,

    -- Relationship description (e.g. 'parent', 'legal_guardian', 'spouse')
    relationship            VARCHAR(50) NOT NULL,

    -- Reference to the uploaded legal document (file path / IPFS CID)
    legal_document_reference TEXT,

    -- Admin who verified and activated this delegation
    granted_by              INT         REFERENCES users(user_id) ON DELETE SET NULL,

    -- Active validity window; NULL valid_to means indefinite
    valid_from              DATE        NOT NULL DEFAULT CURRENT_DATE,
    valid_to                DATE,

    -- 'pending' until admin verifies; 'active' once approved;
    -- 'revoked' if cancelled by patient, guardian, or admin
    status                  VARCHAR(10) NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'active', 'revoked')),

    created_at              TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- PORTAL_SESSIONS TABLE
-- Patient-portal login sessions kept in a separate table from
-- the general sessions table so that a compromised hospital
-- session cannot be replayed against the patient portal.
-- Structure mirrors sessions but is scoped to role = 'patient'.
-- ============================================================
CREATE TABLE portal_sessions (
    session_id      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Must be a patient-role user
    user_id         INT         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,

    device_info     TEXT,
    ip_address      INET,

    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- Hard expiry checked on every authenticated patient-portal request
    expires_at      TIMESTAMP   NOT NULL,

    revoked         BOOLEAN     DEFAULT FALSE,
    mfa_verified    BOOLEAN     DEFAULT FALSE
);

-- ============================================================
-- FHIR_RESOURCE_MAP TABLE
-- Maps each internal medical_records row to its corresponding
-- FHIR Resource.id and resource type so the platform can
-- participate in national health exchanges (ABDM, HL7 FHIR R4)
-- without polluting the core medical_records table with
-- FHIR-specific columns.
-- ============================================================
CREATE TABLE fhir_resource_map (
    map_id              SERIAL PRIMARY KEY,

    -- The HCH internal record this mapping covers
    record_id           INT         UNIQUE NOT NULL REFERENCES medical_records(record_id) ON DELETE CASCADE,

    -- FHIR Resource.id (server-assigned UUID on the FHIR server)
    fhir_resource_id    VARCHAR(64) UNIQUE NOT NULL,

    -- FHIR resource type (R4 resource names)
    fhir_resource_type  VARCHAR(50) NOT NULL
                        CHECK (fhir_resource_type IN (
                            'DiagnosticReport',
                            'Observation',
                            'DocumentReference',
                            'ImagingStudy',
                            'MedicationRequest',
                            'AllergyIntolerance',
                            'Condition',
                            'Procedure'
                        )),

    -- Base URL of the FHIR server that hosts this resource
    fhir_server_url     VARCHAR(255) NOT NULL,

    -- Version tag returned by the FHIR server (ETag / meta.versionId)
    fhir_version_id     VARCHAR(64),

    -- Timestamp of the last successful sync to the FHIR server
    last_synced_at      TIMESTAMP,

    -- 'synced' = in sync; 'pending' = queued for first push;
    -- 'stale'  = local record updated, FHIR not yet refreshed;
    -- 'error'  = last sync attempt failed
    sync_status         VARCHAR(10) NOT NULL DEFAULT 'pending'
                        CHECK (sync_status IN ('synced', 'pending', 'stale', 'error')),

    created_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- SEGMENT 6: INDEXES FOR IMPORTANT MISSING TABLES
-- ============================================================

-- NOTIFICATIONS
-- Most common query: all unread notifications for a recipient
CREATE INDEX idx_notif_recipient_id     ON notifications (recipient_id);
-- Undelivered notifications for retry worker
CREATE INDEX idx_notif_undelivered      ON notifications (delivered_at) WHERE delivered_at IS NULL;
-- Unread notifications for badge counter
CREATE INDEX idx_notif_unread           ON notifications (recipient_id, read_at) WHERE read_at IS NULL;
-- Type filter (e.g. all consent_request notifications)
CREATE INDEX idx_notif_type             ON notifications (type, created_at);

-- SUBSCRIPTION_EVENTS
-- All events for a given hospital (billing history page)
CREATE INDEX idx_sub_hospital_id        ON subscription_events (hospital_id);
-- Event type filter (e.g. all 'expired' events for alerts)
CREATE INDEX idx_sub_event_type         ON subscription_events (event_type, created_at);
-- Date range queries for billing reports
CREATE INDEX idx_sub_valid_from         ON subscription_events (valid_from, valid_to);

-- CONSENT_POLICIES
-- All standing policies for a patient
CREATE INDEX idx_cp_patient_id          ON consent_policies (patient_id);
-- All policies granted to a specific requester
CREATE INDEX idx_cp_grantee_id          ON consent_policies (grantee_id);
-- Active-policy lookup at access-check time
CREATE INDEX idx_cp_patient_active      ON consent_policies (patient_id, status) WHERE status = 'active';
-- Hospital-scoped policies
CREATE INDEX idx_cp_hospital_id         ON consent_policies (hospital_id);

-- PATIENT_DEVICES
-- All devices registered to a patient
CREATE INDEX idx_pd_patient_id          ON patient_devices (patient_id);
-- Active (non-revoked) devices — partial index for key-revocation checks
CREATE INDEX idx_pd_active              ON patient_devices (patient_id) WHERE revoked_at IS NULL;

-- PATIENT_PREFERENCES
-- patient_id is already UNIQUE (implicit B-tree); explicit for readability
CREATE UNIQUE INDEX idx_pp_patient_id   ON patient_preferences (patient_id);

-- DEPENDENT_ACCESS
-- All delegations where a user is acting as guardian
CREATE INDEX idx_da_guardian_id         ON dependent_access (guardian_id);
-- All delegations covering a specific patient
CREATE INDEX idx_da_patient_id          ON dependent_access (patient_id);
-- Active delegations only
CREATE INDEX idx_da_active              ON dependent_access (patient_id, status) WHERE status = 'active';

-- PORTAL_SESSIONS
-- Per-user portal session lookup
CREATE INDEX idx_ps_user_id             ON portal_sessions (user_id);
-- Expiry cleanup job
CREATE INDEX idx_ps_expires_at          ON portal_sessions (expires_at);
-- Active (non-revoked) session fast path
CREATE INDEX idx_ps_active              ON portal_sessions (user_id, revoked) WHERE revoked = FALSE;

-- FHIR_RESOURCE_MAP
-- record_id is already UNIQUE (implicit B-tree); explicit for readability
CREATE UNIQUE INDEX idx_fhir_record_id  ON fhir_resource_map (record_id);
-- FHIR server URL + type filter (list all DiagnosticReports on a server)
CREATE INDEX idx_fhir_server_type       ON fhir_resource_map (fhir_server_url, fhir_resource_type);
-- Sync-status filter for the sync worker
CREATE INDEX idx_fhir_sync_status       ON fhir_resource_map (sync_status) WHERE sync_status IN ('pending', 'stale', 'error');


-- ============================================================
-- SEGMENT 6 SEED DATA
-- ============================================================

-- ============================================================
-- PATIENT_PREFERENCES — one row per patient (all three seed patients)
-- ============================================================
INSERT INTO patient_preferences (patient_id, auto_approve_same_hospital, notification_channel, language, timezone, analytics_opt_in)
VALUES
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN'),
    FALSE,
    'both',       -- Rohan wants email + SMS
    'en',
    'Asia/Kolkata',
    TRUE
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=amina.rahman@hch,OU=patient,O=HCH,C=IN'),
    TRUE,         -- Amina auto-approves her own hospital
    'email',
    'en',
    'Asia/Kolkata',
    FALSE
),
(
    (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=joseph.daniel@hch,OU=patient,O=HCH,C=IN'),
    FALSE,
    'sms',
    'en',
    'Asia/Kolkata',
    FALSE
);

-- ============================================================
-- NOTIFICATIONS — in-app notifications for the two existing
-- access_consent rows and the three record_uploaded events
-- ============================================================
INSERT INTO notifications (recipient_id, type, channel, reference_id, message, delivered_at, read_at)
VALUES
(
    -- Notify Rohan that Sunrise Medical requested access to his blood test
    (SELECT user_id FROM users WHERE username = 'rohan'),
    'consent_request',
    'in_app',
    (SELECT consent_id FROM access_consent WHERE smart_contract_tx_id IS NULL
        AND patient_id = (SELECT patient_id FROM patients WHERE fabric_identity = 'CN=rohan.sharma@hch,OU=patient,O=HCH,C=IN')),
    'Sunrise Medical Center has requested access to your Blood Test Report. Please review.',
    CURRENT_TIMESTAMP,
    NULL    -- Not yet read
),
(
    -- Notify Amina that City Care was granted access to her X-ray
    (SELECT user_id FROM users WHERE username = 'amina'),
    'access_granted',
    'in_app',
    (SELECT consent_id FROM access_consent WHERE smart_contract_tx_id = 'fab1tx_consent_amina_xray_citycare'),
    'City Care Hospital has been granted access to your X-Ray Report until 05-Jul-2026.',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP   -- Amina has already read this
),
(
    -- Notify Rohan that a new record was uploaded for him
    (SELECT user_id FROM users WHERE username = 'rohan'),
    'record_uploaded',
    'email',
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2'),
    'A new Blood Test Report has been uploaded to your health record by City Care Hospital.',
    CURRENT_TIMESTAMP,
    NULL
),
(
    -- Notify Amina of her record upload
    (SELECT user_id FROM users WHERE username = 'amina'),
    'record_uploaded',
    'email',
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    'A new X-Ray Report has been uploaded to your health record by City Care Hospital.',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
),
(
    -- Notify Joseph of his discharge summary upload
    (SELECT user_id FROM users WHERE username = 'joseph'),
    'record_uploaded',
    'sms',
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'),
    'A new Discharge Summary has been uploaded to your health record by City Care Hospital.',
    CURRENT_TIMESTAMP,
    NULL
);

-- ============================================================
-- SUBSCRIPTION_EVENTS — billing history for City Care (active)
-- and Central Health Clinic (active); Sunrise has no paid events
-- ============================================================
INSERT INTO subscription_events (hospital_id, event_type, plan_name, amount, currency, invoice_reference, valid_from, valid_to)
VALUES
(
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'activated',
    'Pro',
    12000.00,
    'INR',
    'INV-2025-H001-001',
    '2025-01-01',
    '2025-12-31'
),
(
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H001'),
    'renewed',
    'Pro',
    12000.00,
    'INR',
    'INV-2026-H001-001',
    '2026-01-01',
    '2026-12-31'
),
(
    (SELECT hospital_id FROM hospitals WHERE license_number = 'LIC-H003'),
    'activated',
    'Basic',
    6000.00,
    'INR',
    'INV-2025-H003-001',
    '2025-09-01',
    '2026-08-15'
);

-- ============================================================
-- FHIR_RESOURCE_MAP — map each seed medical record to a
-- representative FHIR resource type on a demo FHIR server
-- ============================================================
INSERT INTO fhir_resource_map (record_id, fhir_resource_id, fhir_resource_type, fhir_server_url, fhir_version_id, last_synced_at, sync_status)
VALUES
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'a3f1e2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2'),
    'fhir-dr-rohan-blood-001',
    'DiagnosticReport',
    'https://fhir.hch.example.com/r4',
    '1',
    CURRENT_TIMESTAMP,
    'synced'
),
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5'),
    'fhir-is-amina-xray-001',
    'ImagingStudy',
    'https://fhir.hch.example.com/r4',
    '1',
    CURRENT_TIMESTAMP,
    'synced'
),
(
    (SELECT record_id FROM medical_records WHERE sha256_hash = 'c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'),
    'fhir-dr-joseph-discharge-001',
    'DocumentReference',
    'https://fhir.hch.example.com/r4',
    '1',
    CURRENT_TIMESTAMP,
    'synced'
);
