// Theme toggle — persisted, respects system preference on first visit
(function initTheme() {
  const root = document.documentElement;
  const toggle = document.getElementById("themeToggle");
  const stored = localStorage.getItem("theme");
  const systemPrefersLight = window.matchMedia("(prefers-color-scheme: light)").matches;
  const startLight = stored ? stored === "light" : systemPrefersLight;

  function applyTheme(light) {
    if (light) {
      root.setAttribute("data-theme", "light");
    } else {
      root.removeAttribute("data-theme");
    }
    if (toggle) {
      toggle.setAttribute("aria-pressed", String(light));
      toggle.setAttribute("aria-label", light ? "Switch to dark theme" : "Switch to light theme");
    }
  }

  applyTheme(startLight);

  if (toggle) {
    toggle.addEventListener("click", () => {
      const isLight = root.getAttribute("data-theme") === "light";
      applyTheme(!isLight);
      localStorage.setItem("theme", !isLight ? "light" : "dark");
    });
  }
})();

// Reveal-on-scroll — one quiet entrance per section, not per element
(function initReveal() {
  const els = document.querySelectorAll(".reveal");
  if (!("IntersectionObserver" in window)) {
    els.forEach((e) => e.classList.add("in-view"));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => entries.forEach((entry) => entry.isIntersecting && entry.target.classList.add("in-view")),
    { threshold: 0.12 }
  );
  els.forEach((e) => io.observe(e));
})();

// Footer year
(function initYear() {
  const year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());
})();
