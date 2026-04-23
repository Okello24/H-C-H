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
                "Welcome, " + data.username;

            // 🖼 profile image (UPDATED FOR SIDEBAR + HEADER)
                const sidebarImg = document.getElementById("adminPic");
                const headerImg = document.getElementById("headerProfilePic");

                console.log("PROFILE PIC VALUE:", data.profile_picture);

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

    fetch("http://127.0.0.1:5000/api/admin/dashboard", {
        credentials: "include"
    })
    .then(res => res.json())
    .then(data => {
        if (data.status === "success") {

            // ✅ Update cards
            document.getElementById("totalHospitals").innerText = data.hospitals;
            document.getElementById("totalPatients").innerText = data.patients;
            document.getElementById("totalUsers").innerText = data.totalUsers;

            // ✅ Update table
            const table = document.getElementById("recordsTable");
            table.innerHTML = ""; // clear old data

            data.records.forEach(record => {
                const row = document.createElement("tr");

                row.innerHTML = `
                    <td>${record[0]}</td>
                    <td>${record[1]}</td>
                    <td>${record[2]}</td>
                    <td>${record[3]}</td>
                    <td>${new Date(record[4]).toLocaleDateString()}</td>
                    <td>${new Date(record[5]).toLocaleDateString()}</td>
                `;

                table.appendChild(row);
            });
        }
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
