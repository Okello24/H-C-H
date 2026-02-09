// Example JavaScript for dynamic dashboard updates

document.addEventListener("DOMContentLoaded", function() {
    console.log("Dashboard loaded successfully.");

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
    document.getElementById("logoutBtn").addEventListener("click", function() {
        alert("You have been logged out.");
        window.location.href = "../login.html";
    });
});

// Simple smooth scroll + dynamic navbar highlight

document.addEventListener("DOMContentLoaded", function() {
    const navLinks = document.querySelectorAll(".navbar a");

    window.addEventListener("scroll", () => {
        let fromTop = window.scrollY + 100;

        navLinks.forEach(link => {
            const section = document.querySelector(link.hash);
            if (section && section.offsetTop <= fromTop && section.offsetTop + section.offsetHeight > fromTop) {
                navLinks.forEach(l => l.classList.remove("active"));
                link.classList.add("active");
            }
        });
    });

    console.log("Homepage loaded successfully.");
});
