from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2

app = Flask(__name__)
CORS(app)  # Allow frontend–backend communication

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

        query = """
        SELECT user_id, username, email, role
        FROM users
        WHERE username = %s AND password_hash = %s AND role = %s
        LIMIT 1;
        """

        cur.execute(query, (username, password, role))
        user = cur.fetchone()

        cur.close()
        conn.close()

        if user:
            return {
                "status": "success",
                "user_id": user[0],
                "username": user[1],
                "email": user[2],
                "role": user[3]
            }
        else:
            return {"status": "error", "message": "Invalid credentials"}

    except Exception as e:
        return {"status": "error", "message": str(e)}


# ----------------------------------------------
# PATIENT LOGIN API
# ----------------------------------------------
@app.route("/api/login/patient", methods=["POST"])
def login_patient():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    result = login_user(username, password, "patient")
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
    return jsonify(result)

# ----------------------------------------------
# SERVER RUN
# ----------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

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
