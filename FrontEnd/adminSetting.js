// Example JavaScript for dynamic dashboard updates

document.addEventListener("DOMContentLoaded", function() {
    console.log("Admin page loaded successfully.");

    fetch("http://127.0.0.1:5000/api/admin/details", {
        credentials: "include"
    })
    .then(res => res.json())
    .then(data => {
        if (data.status === "success") {

            document.getElementById("adminName").innerText = data.username;
            document.getElementById("adminEmail").innerText = data.email;
            document.getElementById("adminPhone").innerText = data.phone;
            // Optional
            document.querySelector(".main-content h1").innerText =
                "Edit your profile from here Mr." + data.username+ " sir";

            // 🖼 profile image (UPDATED FOR SIDEBAR + HEADER)
                const sidebarImg = document.getElementById("adminPic");
                const headerImg = document.getElementById("headerProfilePic");

                console.log("FINAL IMAGE URL:", "http://127.0.0.1:5000/" + data.profile_picture);

                let imageUrl;

                if (data.profile_picture && data.profile_picture !== "null") {
                    imageUrl = "http://127.0.0.1:5000/" + data.profile_picture;
                } else {
                    imageUrl = "http://127.0.0.1:5000/uploads/defaultProfile.webp"; 
                }
                //  apply safely
                if (sidebarImg) sidebarImg.src = imageUrl;
                if (headerImg) headerImg.src = imageUrl;
            }
    });

    //PROFILE UPDATES CODES FOR MAKING CHANGES TO ADMIN'S PROFILE
    document.getElementById("profileForm").addEventListener("submit", function(e) {
    e.preventDefault();

    const formData = new FormData();

    const name = document.getElementById("name").value;
    const email = document.getElementById("email").value;
    const phone = document.getElementById("phoneNo").value;
    const password = document.getElementById("password").value;
    const confirmPassword = document.getElementById("confirmPassword").value;

    const fileInput = document.getElementById("profile");

    // 🔐 Password validation (frontend)
    if (password && password !== confirmPassword) {
        alert("❌ Passwords do not match");
        return;
    }

    // Append only filled fields
    if (name) formData.append("name", name);
    if (email) formData.append("email", email);
    if (phone) formData.append("phone", phone);
    if (password) formData.append("password", password);
    if (confirmPassword) formData.append("confirmPassword", confirmPassword);

    if (fileInput.files.length > 0) {
        formData.append("profile", fileInput.files[0]);
    }

    fetch("http://127.0.0.1:5000/api/admin/update-profile", {
        method: "POST",
        credentials: "include",
        body: formData
    })
    .then(res => res.json())
    .then(data => {
        console.log("SERVER RESPONSE:", data);

        if (data.status === "success") {

            // 🎯 SMART SUCCESS MESSAGES
            if (password) {
                alert("✅ Password updated successfully");
            } else if (fileInput.files.length > 0) {
                alert("✅ Profile picture updated successfully");
            } else {
                alert("✅ Profile details updated successfully");
            }

            location.reload();

        } else {
            // 🎯 SMART ERROR MESSAGES
            if (data.message.includes("Passwords")) {
                alert("❌ Password error: " + data.message);
            } else if (fileInput.files.length > 0) {
                alert("❌ Image upload failed:" + data.message);
            } else {
                alert("❌ Update failed: " + data.message);
            }
        }
    })
    .catch(err => {
        console.error(err);
        alert("❌ Server error. Check backend.");
    });
});

    // Logout button behavior
    document.getElementById("logoutBtn").addEventListener("click", function(e) {
    e.preventDefault();

    fetch("http://127.0.0.1:5000/api/logout", {
        method: "POST",
        credentials: "include"
    })
    .then(() => {
        alert("Logged out successfully");
        window.location.href = "login.html";
    });
    });

    document.getElementById("sidelogoutBtn").addEventListener("click", function(e) {
    e.preventDefault();

    fetch("http://127.0.0.1:5000/api/logout", {
        method: "POST",
        credentials: "include"
    })
    .then(() => {
        alert("Logged out successfully");
        window.location.href = "login.html";
    });
    });
});

