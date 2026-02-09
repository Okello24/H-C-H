-- ============================================================
--   EHR BLOCKCHAIN SYSTEM - REDUCED SCHEMA (POSTGRESQL)
--   Includes: Users, Patients, Hospitals, Admins
-- ============================================================

-- Drop tables in correct order
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS hospitals CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================
-- USERS TABLE (Central Login System for ALL ROLES)
-- ============================================================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('patient', 'hospital', 'admin')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- PATIENTS TABLE (Patient Profile Info)
-- ============================================================
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,
    date_of_birth DATE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    address TEXT NOT NULL,
    gender VARCHAR(20),
    blockchain_wallet VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- HOSPITALS TABLE (Hospital Registration Info)
-- ============================================================
CREATE TABLE hospitals (
    hospital_id SERIAL PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    hospital_name VARCHAR(200) NOT NULL,
    license_number VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    address TEXT NOT NULL,
    subscription_status VARCHAR(20) DEFAULT 'inactive'
        CHECK (subscription_status IN ('active', 'inactive')),
    subscription_expiry DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ADMINS TABLE (Admin Profile Info)
-- *MODIFIED* to include email & password for login
-- ============================================================
CREATE TABLE admins (
    admin_id SERIAL PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,

    -- Added for login:
    email VARCHAR(150) UNIQUE NOT NULL,

    admin_level INT DEFAULT 1, -- 1 = Normal admin, 2 = Super admin
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- INSERT ADMINS INTO USERS
-- ============================
INSERT INTO users (username, email, password_hash, role)
VALUES
('emmanuel', 'emmanuel@gmail.com', 'Emma432', 'admin'),
('jimmy', 'jimmy@gmail.com', 'Jimm432', 'admin'),
('william', 'william@gmail.com', 'Will432', 'admin'),
('khamis', 'khamis@gmail.com', 'Kham432', 'admin');

-- ============================
-- INSERT INTO ADMINS (link by user_id)
-- ============================
INSERT INTO admins (user_id, full_name, email, admin_level)
VALUES
(1, 'Emmanuel', 'emmanuel@gmail.com', 2),
(2, 'Jimmy', 'jimmy@gmail.com', 1),
(3, 'William', 'william@gmail.com', 1),
(4, 'Khamis', 'khamis@gmail.com', 1);

-- ============================
-- INSERT HOSPITAL USERS
-- ============================
INSERT INTO users (username, email, password_hash, role)
VALUES
('citycare', 'citycare@example.com', 'Hosp123', 'hospital'),
('sunrise', 'sunrise@example.com', 'Sun789', 'hospital'),
('central', 'central@example.com', 'Cent456', 'hospital');

-- ============================
-- INSERT INTO HOSPITALS
-- ============================
INSERT INTO hospitals (user_id, hospital_name, license_number, email, phone, address, subscription_status, subscription_expiry)
VALUES
(5, 'City Care Hospital', 'LIC-H001', 'citycare@example.com', '+91-9823456711', 'Plot 12, Green Avenue, Delhi', 'active', '2026-12-31'),
(6, 'Sunrise Medical Center', 'LIC-H002', 'sunrise@example.com', '+91-9988776612', '45 MG Road, Bengaluru', 'inactive', NULL),
(7, 'Central Health Clinic', 'LIC-H003', 'central@example.com', '+91-7788994411', '89 Park Street, Kolkata', 'active', '2026-08-15');

-- ============================
-- INSERT PATIENT USERS
-- ============================
INSERT INTO users (username, email, password_hash, role)
VALUES
('rohan', 'rohan@example.com', 'Rohan12', 'patient'),
('amina', 'amina@example.com', 'Amina34', 'patient'),
('joseph', 'joseph@example.com', 'Jose56', 'patient');

-- ============================
-- INSERT INTO PATIENTS
-- ============================
INSERT INTO patients (user_id, full_name, date_of_birth, phone, address, gender, blockchain_wallet)
VALUES
(8, 'Rohan Sharma', '1998-04-12', '+91-9001234567', 'Sector 22, Chandigarh', 'Male', '0xA34BC101FF99'),
(9, 'Amina Rahman', '2000-09-30', '+91-8887654321', 'Old City, Hyderabad', 'Female', '0xFF11CD909AA1'),
(10, 'Joseph Daniel', '1995-01-15', '+91-9123456789', 'Marine Drive, Mumbai', 'Male', '0xBEEF019283AA');
