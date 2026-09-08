(function () {
  "use strict";

  var root = document.documentElement;

  /* ---------- Footer year ---------- */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  /* ---------- Theme toggle ---------- */
  var themeToggle = document.getElementById("themeToggle");
  var THEME_KEY = "portfolio-theme";

  function applyTheme(theme) {
    if (theme === "light") {
      root.setAttribute("data-theme", "light");
      if (themeToggle) {
        themeToggle.setAttribute("aria-pressed", "true");
        themeToggle.setAttribute("aria-label", "Switch to dark theme");
      }
    } else {
      root.removeAttribute("data-theme");
      if (themeToggle) {
        themeToggle.setAttribute("aria-pressed", "false");
        themeToggle.setAttribute("aria-label", "Switch to light theme");
      }
    }
  }

  var savedTheme = null;
  try {
    savedTheme = localStorage.getItem(THEME_KEY);
  } catch (e) {
    savedTheme = null;
  }

  if (savedTheme) {
    applyTheme(savedTheme);
  } else if (window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches) {
    applyTheme("light");
  }

  if (themeToggle) {
    themeToggle.addEventListener("click", function () {
      var isLight = root.getAttribute("data-theme") === "light";
      var next = isLight ? "dark" : "light";
      applyTheme(next);
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch (e) {
        /* storage unavailable — theme still applies for this session */
      }
    });
  }

  /* ---------- Reveal on scroll (one quiet entrance per block) ---------- */
  var revealEls = document.querySelectorAll(".reveal");
  if (revealEls.length) {
    if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add("in-view");
              io.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.15 }
      );
      revealEls.forEach(function (el) {
        io.observe(el);
      });
    } else {
      revealEls.forEach(function (el) {
        el.classList.add("in-view");
      });
    }
  }

  /* ---------- Project tag filter ---------- */
  var grid = document.getElementById("projectGrid");
  var filterWrap = document.getElementById("filters");

  if (grid && filterWrap) {
    var cards = Array.prototype.slice.call(grid.querySelectorAll(".project-card"));
    var tagSet = [];

    cards.forEach(function (card) {
      (card.getAttribute("data-tags") || "").split(",").forEach(function (tag) {
        tag = tag.trim();
        if (tag && tagSet.indexOf(tag) === -1) tagSet.push(tag);
      });
    });

    function labelFor(tag) {
      var map = { iac: "IaC", aws: "AWS", nfs: "NFS" };
      if (map[tag]) return map[tag];
      return tag.charAt(0).toUpperCase() + tag.slice(1);
    }

    function setActive(tag) {
      Array.prototype.slice.call(filterWrap.children).forEach(function (btn) {
        btn.setAttribute("aria-pressed", btn.dataset.tag === tag ? "true" : "false");
      });
      cards.forEach(function (card) {
        var tags = (card.getAttribute("data-tags") || "").split(",");
        var show = tag === "all" || tags.indexOf(tag) !== -1;
        card.hidden = !show;
      });
    }

    var allChip = document.createElement("button");
    allChip.type = "button";
    allChip.className = "chip";
    allChip.textContent = "All";
    allChip.dataset.tag = "all";
    allChip.addEventListener("click", function () {
      setActive("all");
    });
    filterWrap.appendChild(allChip);

    tagSet.forEach(function (tag) {
      var chip = document.createElement("button");
      chip.type = "button";
      chip.className = "chip";
      chip.textContent = labelFor(tag);
      chip.dataset.tag = tag;
      chip.addEventListener("click", function () {
        setActive(tag);
      });
      filterWrap.appendChild(chip);
    });

    setActive("all");
  }

  /* ---------- Active nav link on scroll ---------- */
  var navLinks = Array.prototype.slice.call(document.querySelectorAll(".primary-nav a"));
  var sections = navLinks
    .map(function (link) {
      var id = link.getAttribute("href");
      return id && id.charAt(0) === "#" ? document.querySelector(id) : null;
    })
    .filter(Boolean);

  if (sections.length && "IntersectionObserver" in window) {
    var navObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var id = "#" + entry.target.id;
          navLinks.forEach(function (link) {
            link.classList.toggle("is-active", link.getAttribute("href") === id);
          });
        });
      },
      { rootMargin: "-45% 0px -50% 0px" }
    );
    sections.forEach(function (section) {
      navObserver.observe(section);
    });
  }
})();
