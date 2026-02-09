const patientBtn = document.getElementById("patientBtn");
const hospitalBtn = document.getElementById("hospitalBtn");
const adminBtn = document.getElementById("adminBtn");

const patientForm = document.getElementById("patientForm");
const hospitalForm = document.getElementById("hospitalForm");
const adminForm = document.getElementById("adminForm");

// RESET ACTIVE STATE
function resetButtons() {
    patientBtn.classList.remove("active");
    hospitalBtn.classList.remove("active");
    adminBtn.classList.remove("active");
}

// RESET FORMS
function hideForms() {
    patientForm.classList.add("hidden");
    hospitalForm.classList.add("hidden");
    adminForm.classList.add("hidden");
}

// Patient Login
patientBtn.onclick = () => {
    resetButtons();
    hideForms();

    patientBtn.classList.add("active");
    patientForm.classList.remove("hidden");
};

// Hospital Login
hospitalBtn.onclick = () => {
    resetButtons();
    hideForms();

    hospitalBtn.classList.add("active");
    hospitalForm.classList.remove("hidden");
};

// Admin Login
adminBtn.onclick = () => {
    resetButtons();
    hideForms();

    adminBtn.classList.add("active");
    adminForm.classList.remove("hidden");
};

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

/* ================= TOGGLE BUTTONS =================
const patientBtn = document.getElementById("patientBtn");
const hospitalBtn = document.getElementById("hospitalBtn");
const adminBtn = document.getElementById("adminBtn");

const patientForm = document.getElementById("patientForm");
const hospitalForm = document.getElementById("hospitalForm");
const adminForm = document.getElementById("adminForm");

// Toggle functions
patientBtn.addEventListener("click", () => toggleForm("patient"));
hospitalBtn.addEventListener("click", () => toggleForm("hospital"));
adminBtn.addEventListener("click", () => toggleForm("admin"));

function toggleForm(type) {
    patientBtn.classList.remove("active");
    hospitalBtn.classList.remove("active");
    adminBtn.classList.remove("active");

    patientForm.classList.add("hidden");
    hospitalForm.classList.add("hidden");
    adminForm.classList.add("hidden");

    if (type === "patient") {
        patientBtn.classList.add("active");
        patientForm.classList.remove("hidden");
    }
    if (type === "hospital") {
        hospitalBtn.classList.add("active");
        hospitalForm.classList.remove("hidden");
    }
    if (type === "admin") {
        adminBtn.classList.add("active");
        adminForm.classList.remove("hidden");
    }
}
*/
// ================= REGEX PATTERNS =================
const regex = {
    username: /^[A-Za-z0-9_]{4,16}$/,
    password: /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@!#$%^&*]{6,20}$/ // letters + numbers
};

// Generic validator function
function validateField(input, pattern, msg) {
    if (!pattern.test(input.value.trim())) {
        alert(msg);
        input.focus();
        return false;
    }
    return true;
}
/*
// ================= PATIENT LOGIN VALIDATION =================
patientForm.addEventListener("submit", (e) => {
    e.preventDefault();

    const username = patientForm.querySelector("input[placeholder='Enter username']");
    const password = patientForm.querySelector("input[placeholder='Enter password']");

    if (!validateField(username, regex.username, "Invalid username! Must be 4–16 characters (letters, numbers, underscore).")) return;
    if (!validateField(password, regex.password, "Password must contain letters & numbers (min 6 characters).")) return;

    alert("Patient login successful!");
});

// ================= HOSPITAL LOGIN VALIDATION =================
hospitalForm.addEventListener("submit", (e) => {
    e.preventDefault();

    const username = hospitalForm.querySelector("input[placeholder='Enter hospital username']");
    const password = hospitalForm.querySelector("input[placeholder='Enter password']");

    if (!validateField(username, regex.username, "Invalid hospital username format.")) return;
    if (!validateField(password, regex.password, "Invalid password format! Must contain letters & numbers.")) return;

    alert("Hospital login successful!");
});

// ================= ADMIN LOGIN VALIDATION =================
adminForm.addEventListener("submit", (e) => {
    e.preventDefault();

    const username = adminForm.querySelector("input[placeholder='Enter admin username']");
    const password = adminForm.querySelector("input[placeholder='Enter password']");

    if (!validateField(username, regex.username, "Admin username must be valid (4–16 chars).")) return;
    if (!validateField(password, regex.password, "Invalid admin password format.")) return;

    alert("Admin login successful!");
});
*/
function login(role) {
    const username = document.querySelector(`#${role}Form input[name='username']`).value;
    const password = document.querySelector(`#${role}Form input[name='password']`).value;

    fetch(`http://localhost:5000/api/login/${role}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password })
    })
    .then(res => res.json())
    .then(data => {
    if (data.status === "success") {
        alert("Login successful!");
        window.location.href = `${role}.html`;
    } else {
        alert(data.message);
    }
})

    .catch(err => {
        alert("Server not responding");
        console.error(err);
    });
}

document.querySelector("#patientForm .submit-btn").onclick = (e) => {
    e.preventDefault();
    login("patient");
};

document.querySelector("#hospitalForm .submit-btn").onclick = (e) => {
    e.preventDefault();
    login("hospital");
};

document.querySelector("#adminForm .submit-btn").onclick = (e) => {
    e.preventDefault();
    login("admin");
};
