// Example JavaScript for dynamic dashboard updates

document.addEventListener("DOMContentLoaded", function() {
    console.log("Admin page loaded successfully.");

    fetch("http://127.0.0.1:5000/api/admin/details", {
        credentials: "include"
    })
    .then(res => res.json())
    .then(data => {
        if (data.status === "success") {

            // // Optional
            document.querySelector(".main-content h1").innerText =
                "Quick analysis for you, Mr."+ data.username +" sir";

            // 🖼 profile image (UPDATED FOR SIDEBAR + HEADER)
                const headerImg = document.getElementById("headerProfilePic");

                console.log("PROFILE PIC VALUE:", data.profile_picture);

                let imageUrl;

                if (data.profile_picture && data.profile_picture !== "null") {
                    imageUrl = "http://127.0.0.1:5000/" + data.profile_picture;
                } else {
                    imageUrl = "http://127.0.0.1:5000/uploads/defaultProfile.webp"; 
                }
                //  apply safely

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
            document.getElementById("activeHospitals").innerText = data.activeHospitals;
            document.getElementById("inactiveHospitals").innerText = data.inactiveHospitals;
            document.getElementById("deletedHospitals").innerText = data.deletedHospitals;

            document.getElementById("totalPatients").innerText = data.patients;
            document.getElementById("activePatients").innerText = data.activePatients;
            document.getElementById("inactivePatients").innerText = data.inactivePatients;
            document.getElementById("deletedPatients").innerText = data.deletedPatients;

            document.getElementById("totalAdmins").innerText = data.totalAdmins;
            document.getElementById("activeAdmins").innerText = data.activeAdmins;
            document.getElementById("inactiveAdmins").innerText = data.inactiveAdmins;
            document.getElementById("deletedAdmins").innerText = data.deletedAdmins;

            document.getElementById("totalUsers").innerText = data.totalUsers;
            document.getElementById("activeUsers").innerText = data.activeUsers;
            document.getElementById("inactiveUsers").innerText = data.inactiveUsers;
            document.getElementById("deletedUsers").innerText = data.deletedUsers;
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

});
