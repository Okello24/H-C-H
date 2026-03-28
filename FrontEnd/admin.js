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

            // Optional
            document.querySelector(".main-content h1").innerText =
                "Welcome, " + data.username;
        }
    });

    // Example of updating stats dynamically
    document.getElementById("totalHospitals").innerText = 15;
    document.getElementById("totalPatients").innerText = 72;
    document.getElementById("transactions").innerText = 310;

    // Simulate adding a new record
    const table = document.getElementById("recordsTable");
    const newRow = document.createElement("tr");
    newRow.innerHTML = `
        <td>103</td>
        <td>Amina Lee</td>
        <td>Cardiac Checkup</td>
        <td>2025-11-13</td>
        <td>0x789ghi...</td>
    `;
    table.appendChild(newRow);

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
