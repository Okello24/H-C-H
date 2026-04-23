from flask import Flask, request, jsonify, session,send_from_directory
from flask_cors import CORS
import psycopg2

from db import get_db
from routes.admin import admin_bp

#---------------------------------------------
#PART OF SESSION
#---------------------------------------------
app = Flask(__name__)

app.secret_key = "super-secret-key"

CORS(app, supports_credentials=True)

app.config['SESSION_COOKIE_SAMESITE'] = "Lax"
app.config['SESSION_COOKIE_SECURE'] = False
 # Allow frontend–backend communication

#----------------------------------------------
#import blueprin
#----------------------------------------------
app.register_blueprint(admin_bp)

# ----------------------------------------------
# DATABASE CONNECTION
# ----------------------------------------------
def get_db():
    return psycopg2.connect(
        host="localhost",
        database="HCHdatabase",
        user="postgres",
        password="Victic24@",
        port="5432"
    )

# ----------------------------------------------
# GENERIC LOGIN FUNCTION (USED BY ALL ROLES)
# ----------------------------------------------
def login_user(username, password, role):
    try:
        conn = get_db()
        cur = conn.cursor()

        # 🔐 Verify password using PostgreSQL crypt (bcrypt)
        cur.execute("""
            SELECT user_id, username, email, phone_number, profile_picture, role
            FROM users
            WHERE username = %s
            AND password_hash = crypt(%s, password_hash)
            AND role = %s
            LIMIT 1;
        """, (username, password, role))

        user = cur.fetchone()

        cur.close()
        conn.close()

        if user:
            return {
                "status": "success",
                "user_id": user[0],
                "username": user[1],
                "email": user[2],
                "phone": user[3],
                "profile_picture": user[4],
                "role": user[5]
            }
        else:
            return {
                "status": "error",
                "message": "Invalid username, password, or role"
            }

    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }
# ----------------------------------------------
# PATIENT LOGIN API
# ----------------------------------------------
@app.route("/api/login/patient", methods=["POST"])
def login_patient():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    result = login_user(username, password, "patient")

    if result["status"] == "success":
        session["user_id"] = result["user_id"]
        session["role"] = result["role"]

    return jsonify(result)

# ----------------------------------------------
# HOSPITAL LOGIN API
# ----------------------------------------------
@app.route("/api/login/hospital", methods=["POST"])
def login_hospital():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    result = login_user(username, password, "hospital")

    if result["status"] == "success":
        session["user_id"] = result["user_id"]
        session["role"] = result["role"]
    return jsonify(result)

# ----------------------------------------------
# ADMIN LOGIN API
# ----------------------------------------------
@app.route("/api/login/admin", methods=["POST"])
def login_admin():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    result = login_user(username, password, "admin")

    if result["status"] == "success":
        session["user_id"] = result["user_id"]
        session["role"] = result["role"]
    return jsonify(result)

@app.route("/test", methods=["POST"])
def test():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT username, password_hash FROM users WHERE username=%s", (username,))
    row = cur.fetchone()

    return jsonify({"db_username": row[0], "db_password": row[1], "sent_password": password})

@app.route("/api/check-session", methods=["GET"])
def check_session():
    if "user_id" in session:
        return jsonify({
            "status": "success",
            "role": session["role"]
        })
    return jsonify({"status": "error"}), 401

@app.route("/api/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"status": "success"})

@app.route("/api/admin/details", methods=["GET"])
def get_admin_details():
    if "user_id" not in session:
        return jsonify({"status": "error"}), 401

    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute("""
            SELECT username, email, phone_number, profile_picture
            FROM users
            WHERE user_id = %s
        """, (session["user_id"],))

        user = cur.fetchone()

        cur.close()
        conn.close()

        if user:
            return jsonify({
                "status": "success",
                "username": user[0],
                "email": user[1],
                "phone":user[2],
                "profile_picture": user[3]                        })

        return jsonify({"status": "error"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

#-----------------------------------------------
#photo upload
#----------------------------------------------
@app.route('/uploads/<path:filename>')
def get_image(filename):
    return send_from_directory('uploads', filename)

# ----------------------------------------------
# SERVER RUN
# ----------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
