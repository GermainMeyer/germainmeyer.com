(function () {
  const yearEl = document.getElementById("year");
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelector(".nav-links");
  const sections = document.querySelectorAll("main section[id]");
  const navLinks = document.querySelectorAll(".nav-links a");

  if (toggle && links) {
    toggle.addEventListener("click", function () {
      const expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", String(!expanded));
      links.classList.toggle("open");
    });

    navLinks.forEach(function (link) {
      link.addEventListener("click", function () {
        links.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  const observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) {
          return;
        }

        navLinks.forEach(function (link) {
          const matches = link.getAttribute("href") === "#" + entry.target.id;
          link.classList.toggle("active", matches);
        });
      });
    },
    {
      rootMargin: "-35% 0px -45% 0px",
      threshold: 0
    }
  );

  sections.forEach(function (section) {
    observer.observe(section);
  });

  document.querySelectorAll(".video-lazy").forEach(function (container) {
    const id = container.getAttribute("data-id");
    const iframe = document.createElement("iframe");
    iframe.setAttribute("src", "about:blank");
    iframe.setAttribute("title", "YouTube video player");
    iframe.setAttribute("frameborder", "0");
    iframe.setAttribute("allow", "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share");
    iframe.setAttribute("referrerpolicy", "strict-origin-when-cross-origin");
    iframe.setAttribute("allowfullscreen", "");
    iframe.setAttribute("playsinline", "");

    function loadVideo() {
      if (window.location.protocol === "file:") {
        window.open("https://www.youtube.com/watch?v=" + id, "_blank", "noopener");
        return;
      }

      iframe.setAttribute("src", "https://www.youtube.com/embed/" + id + "?autoplay=1&playsinline=1&vq=hd720");
      container.innerHTML = "";
      container.appendChild(iframe);
      container.classList.remove("video-lazy");
    }

    container.addEventListener("click", loadVideo);
    container.addEventListener("keydown", function (event) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        loadVideo();
      }
    });
  });
})();
