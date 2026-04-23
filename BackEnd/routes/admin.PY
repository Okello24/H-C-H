from flask import Blueprint, jsonify, session
from db import get_db
from flask import request
import os
from werkzeug.utils import secure_filename
from flask import send_from_directory

admin_bp = Blueprint("admin", __name__)

os.makedirs("uploads", exist_ok=True)
UPLOAD_FOLDER = os.path.join(os.getcwd(), "uploads")


#records display for adminRecord
@admin_bp.route("/api/admin/dashboard", methods=["GET"])
def admin_dashboard():
    if "user_id" not in session:
        return jsonify({"status": "error"}), 401

    try:
        conn = get_db()
        cur = conn.cursor()

        # COUNTS HOSPITASL QUERIES
        cur.execute("SELECT COUNT(*) FROM users WHERE role='hospital'")
        hospitals = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='hospital' AND is_active = true ")
        activeHospitals = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='hospital' AND is_active = false ")
        inactiveHospitals = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='hospital' AND is_deleted = true ")
        deletedHospitals = cur.fetchone()[0]

        # COUNTS PATIENTS QUERIES
        cur.execute("SELECT COUNT(*) FROM users WHERE role='patient'")
        patients = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='patient' AND is_active = true ")
        activePatients = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='patient' AND is_active = false ")
        inactivePatients = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='patient' AND is_deleted = true ")
        deletedPatients = cur.fetchone()[0]

        # COUNTS ADMINS QUERIES
        cur.execute("SELECT COUNT(*) FROM users WHERE role='admin'")
        totalAdmins = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='admin' AND is_active = true ")
        activeAdmins = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='admin' AND is_active = false ")
        inactiveAdmins = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE role='admin' AND is_deleted = true ")
        deletedAdmins = cur.fetchone()[0]

        # COUNTS OVERALL QUERIES
        cur.execute("SELECT COUNT(*) FROM users")
        totalUsers = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE is_active = true ")
        activeUsers = cur.fetchone()[0]
    
        cur.execute("SELECT COUNT(*) FROM users WHERE is_active = false ")
        inactiveUsers = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM users WHERE is_deleted = true ")
        deletedUsers = cur.fetchone()[0]


        # REAL TABLE DATA
        cur.execute("""
            SELECT user_id, username, role, email, created_at, updated_at
            FROM users
            WHERE role='patient' OR role='hospital'
            ORDER BY created_at DESC
            LIMIT 9
        """)
        records = cur.fetchall()

        cur.close()
        conn.close()

        # SINGLE RETURN ONLY
        return jsonify({
            "status": "success",

            "hospitals": hospitals,
            "activeHospitals": activeHospitals,
            "inactiveHospitals":inactiveHospitals,
            "deletedHospitals":deletedHospitals,

            "patients": patients,
            "activePatients": activePatients,
            "inactivePatients":inactivePatients,
            "deletedPatients":deletedPatients,

            "totalAdmins": totalAdmins,
            "activeAdmins": activeAdmins,
            "inactiveAdmins": inactiveAdmins,
            "deletedAdmins": deletedAdmins,

            "totalUsers": totalUsers,
            "activeUsers": activeUsers,
            "inactiveUsers":inactiveUsers,
            "deletedUsers":deletedUsers,
            
            "records": records
        })

    except Exception as e:
        print("❌ ERROR:", str(e))
        return jsonify({"status": "error", "message": str(e)})
    

#PROFILE FORM SETTING FOR PROFILE UPDATES 

@admin_bp.route("/api/admin/update-profile", methods=["POST"])
def update_profile():
    if "user_id" not in session:
        return jsonify({"status": "error"}), 401

    try:
        conn = get_db()
        cur = conn.cursor()

        user_id = session["user_id"]

        # Get form data
        name = request.form.get("name")
        email = request.form.get("email")
        phone = request.form.get("phone")
        password = request.form.get("password")
        confirm_password = request.form.get("confirmPassword")

        file = request.files.get("profile")

        updates = []
        values = []

        # ✅ NAME
        if name:
            updates.append("username = %s")
            values.append(name)

        # ✅ EMAIL
        if email:
            updates.append("email = %s")
            values.append(email)

        # ✅ PHONE
        if phone:
            updates.append("phone_number = %s")
            values.append(phone)

        # 🔐 PASSWORD CHECK
        if password:
            if password != confirm_password:
                return jsonify({"status": "error", "message": "Passwords do not match"})

            updates.append("password_hash = crypt(%s, gen_salt('bf', 12))")
            values.append(password)

        # 🖼 IMAGE UPLOAD
        # 🖼 IMAGE UPLOAD
        if file and file.filename != "":
            try:
                filename = secure_filename(file.filename)

                # ensure folder exists
                os.makedirs("uploads", exist_ok=True)

                filepath = os.path.join("uploads", filename)
                file.save(filepath)

                updates.append("profile_picture = %s")
                values.append(f"uploads/{filename}")

                print("✅ FILE SAVED AT:", filepath)

            except Exception as img_error:
                print("❌ IMAGE SAVE ERROR:", str(img_error))
                return jsonify({"status": "error", "message": str(img_error)})

            # # ✅ DEBUG HERE (inside function)
            # print("FILE RECEIVED:", file)
            # print("PASSWORD RECEIVED:", password)

        # ❌ NOTHING TO UPDATE
        if not updates:
            return jsonify({"status": "error", "message": "No changes provided"})

        # ✅ FINAL QUERY
        query = f"""
            UPDATE users
            SET {", ".join(updates)}
            WHERE user_id = %s
        """

        values.append(user_id)

        cur.execute(query, tuple(values))
        conn.commit()

        cur.close()
        conn.close()

        return jsonify({"status": "success"})

    except Exception as e:
        print("❌ ERROR:", str(e))
        return jsonify({"status": "error", "message": str(e)})
    

# @admin_bp.route('/uploads/<path:filename>')
# def serve_uploads(filename):
#     from flask import send_from_directory
#     return send_from_directory('uploads', filename)
