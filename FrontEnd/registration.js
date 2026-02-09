const patientBtn = document.getElementById("patientBtn");
const hospitalBtn = document.getElementById("hospitalBtn");

const patientForm = document.getElementById("patientForm");
const hospitalForm = document.getElementById("hospitalForm");

// Toggle for Patient
patientBtn.onclick = () => {
    patientBtn.classList.add("active");
    hospitalBtn.classList.remove("active");

    patientForm.classList.remove("hidden");
    hospitalForm.classList.add("hidden");
};

// Toggle for Hospital
hospitalBtn.onclick = () => {
    hospitalBtn.classList.add("active");
    patientBtn.classList.remove("active");

    hospitalForm.classList.remove("hidden");
    patientForm.classList.add("hidden");
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

/* =========== FORM TOGGLING ===========
const patientBtn = document.getElementById("patientBtn");
const hospitalBtn = document.getElementById("hospitalBtn");

const patientForm = document.getElementById("patientForm");
const hospitalForm = document.getElementById("hospitalForm");
const adminForm = document.getElementById("adminForm"); // If added

patientBtn.addEventListener("click", () => {
    patientBtn.classList.add("active");
    hospitalBtn.classList.remove("active");

    patientForm.classList.remove("hidden");
    hospitalForm.classList.add("hidden");

    if (adminForm) adminForm.classList.add("hidden");
});

hospitalBtn.addEventListener("click", () => {
    hospitalBtn.classList.add("active");
    patientBtn.classList.remove("active");

    hospitalForm.classList.remove("hidden");
    patientForm.classList.add("hidden");

    if (adminForm) adminForm.classList.add("hidden");
});
*/
// ============= REGEX PATTERNS ============
const regex = {
    name: /^[A-Za-z ]{3,50}$/,  
    username: /^[A-Za-z0-9_]{4,16}$/,
    email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    phone: /^[0-9]{7,15}$/,
    password: /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@!#$%^&*]{6,20}$/,
    hospitalReg: /^[A-Z0-9-]{5,20}$/ // Example: GOV-12345
};

// ============ GENERIC VALIDATION FUNCTION ============
function validateInput(input, pattern, message) {
    if (!pattern.test(input.value.trim())) {
        alert(message);
        input.focus();
        return false;
    }
    return true;
}

// ============ PATIENT FORM VALIDATION ============
if (patientForm) {
    patientForm.addEventListener("submit", (e) => {
        e.preventDefault();

        const fullName = patientForm.querySelector("input[placeholder='Enter full name']");
        const email = patientForm.querySelector("input[placeholder='Enter email']");
        const phone = patientForm.querySelector("input[placeholder='Enter phone number']");
        const username = patientForm.querySelector("input[placeholder='Choose username']");
        const password = patientForm.querySelector("input[placeholder='Create password']");
        const hospitalSelect = patientForm.querySelector("select");

        if (!validateInput(fullName, regex.name, "Full name must contain only letters, min 3 characters.")) return;
        if (!validateInput(email, regex.email, "Enter a valid email address.")) return;
        if (!validateInput(phone, regex.phone, "Phone number must be digits only (7–15 digits).")) return;
        if (!validateInput(username, regex.username, "Username must be 4–16 characters (letters, numbers, underscore).")) return;
        if (!validateInput(password, regex.password, "Password must contain letters & numbers (min 6 chars).")) return;

        if (hospitalSelect.selectedIndex === 0) {
            alert("Please select your hospital.");
            return;
        }

        alert("Patient registration successful!");
        patientForm.reset();
    });
}

// ============ HOSPITAL FORM VALIDATION ============
if (hospitalForm) {
    hospitalForm.addEventListener("submit", (e) => {
        e.preventDefault();

        const hName = hospitalForm.querySelector("input[placeholder='Enter hospital name']");
        const hReg = hospitalForm.querySelector("input[placeholder='Government license number']");
        const email = hospitalForm.querySelector("input[placeholder='Official email']");
        const phone = hospitalForm.querySelector("input[placeholder='Official phone number']");
        const adminName = hospitalForm.querySelector("input[placeholder='Contact person name']");
        const username = hospitalForm.querySelector("input[placeholder='Choose username']");
        const password = hospitalForm.querySelector("input[placeholder='Create password']");
        const planSelect = hospitalForm.querySelector("select");

        if (!validateInput(hName, regex.name, "Hospital name must be alphabetical letters only.")) return;
        if (!validateInput(hReg, regex.hospitalReg, "Invalid hospital registration number. (Format: ABC-12345)")) return;
        if (!validateInput(email, regex.email, "Enter a valid official hospital email.")) return;
        if (!validateInput(phone, regex.phone, "Phone number must be digits only (7–15 digits).")) return;
        if (!validateInput(adminName, regex.name, "Hospital admin name must be valid.")) return;
        if (!validateInput(username, regex.username, "Invalid username format.")) return;
        if (!validateInput(password, regex.password, "Password must contain letters & numbers.")) return;

        if (planSelect.selectedIndex === 0) {
            alert("Please choose a subscription plan.");
            return;
        }

        alert("Hospital registration successful!");
        hospitalForm.reset();
    });
}

// ============ OPTIONAL ADMIN FORM VALIDATION ============
if (adminForm) {
    adminForm.addEventListener("submit", (e) => {
        e.preventDefault();

        const username = adminForm.querySelector("input[name='adminUser']");
        const password = adminForm.querySelector("input[name='adminPass']");

        if (!validateInput(username, regex.username, "Invalid admin username.")) return;
        if (!validateInput(password, regex.password, "Invalid admin password format.")) return;

        alert("Admin registration successful!");
        adminForm.reset();
    });
}

