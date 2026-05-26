/* ============================================================
   BISWAJIT CHANDRA DAS — Portfolio Scripts
   Particles · Cursor · Typing · Scroll Reveal · Skill Bars
   ============================================================ */

'use strict';

/* ── Particle Canvas ─────────────────────────────────────────── */
(function initParticles() {
  const canvas = document.getElementById('particleCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  let W = window.innerWidth, H = window.innerHeight;
  let particles = [];
  let mouse = { x: W / 2, y: H / 2 };

  const COUNT    = Math.min(Math.floor(W * H / 8000), 120);
  const COLORS   = ['#00d4ff', '#0066ff', '#7c3aed', '#00ff9d'];
  const MAX_DIST = 130;

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
  }

  class Particle {
    constructor() { this.reset(true); }

    reset(initial = false) {
      this.x  = Math.random() * W;
      this.y  = initial ? Math.random() * H : H + 10;
      this.vx = (Math.random() - 0.5) * 0.3;
      this.vy = -(Math.random() * 0.4 + 0.1);
      this.r  = Math.random() * 1.5 + 0.5;
      this.alpha  = Math.random() * 0.5 + 0.1;
      this.color  = COLORS[Math.floor(Math.random() * COLORS.length)];
      this.twinkle = Math.random() * Math.PI * 2;
    }

    update() {
      this.twinkle += 0.02;
      this.alpha = 0.15 + Math.sin(this.twinkle) * 0.12;
      this.x += this.vx;
      this.y += this.vy;
      if (this.y < -10 || this.x < -10 || this.x > W + 10) this.reset();
    }

    draw() {
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fillStyle = this.color;
      ctx.globalAlpha = this.alpha;
      ctx.fill();
    }
  }

  function init() {
    particles = Array.from({ length: COUNT }, () => new Particle());
  }

  function drawConnections() {
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx = particles[i].x - particles[j].x;
        const dy = particles[i].y - particles[j].y;
        const d  = Math.sqrt(dx * dx + dy * dy);
        if (d < MAX_DIST) {
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          const alpha = (1 - d / MAX_DIST) * 0.06;
          ctx.strokeStyle = `rgba(0,212,255,${alpha})`;
          ctx.globalAlpha = 1;
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }
  }

  function loop() {
    ctx.clearRect(0, 0, W, H);
    drawConnections();
    particles.forEach(p => { p.update(); p.draw(); });
    ctx.globalAlpha = 1;
    requestAnimationFrame(loop);
  }

  window.addEventListener('resize', resize, { passive: true });
  window.addEventListener('mousemove', e => {
    mouse.x = e.clientX; mouse.y = e.clientY;
  }, { passive: true });

  resize();
  init();
  loop();
})();

/* ── Custom Cursor ───────────────────────────────────────────── */
(function initCursor() {
  const dot  = document.getElementById('cursorDot');
  const ring = document.getElementById('cursorRing');
  if (!dot || !ring) return;

  let mx = 0, my = 0, rx = 0, ry = 0;

  window.addEventListener('mousemove', e => {
    mx = e.clientX; my = e.clientY;
    dot.style.left = mx + 'px';
    dot.style.top  = my + 'px';
  }, { passive: true });

  function animateRing() {
    rx += (mx - rx) * 0.12;
    ry += (my - ry) * 0.12;
    ring.style.left = rx + 'px';
    ring.style.top  = ry + 'px';
    requestAnimationFrame(animateRing);
  }
  animateRing();
})();

/* ── Typing Effect ───────────────────────────────────────────── */
(function initTyping() {
  const el = document.getElementById('typingText');
  if (!el) return;

  const phrases = [
    'AI & Data Analytics Enthusiast',
    'Aspiring AI Researcher',
    'Machine Learning Explorer',
    'Research-Oriented Developer',
    'Generative AI Investigator',
    'Cybersecurity ML Researcher',
  ];

  let phraseIdx = 0, charIdx = 0, deleting = false;
  const typeSpeed   = 60;
  const deleteSpeed = 35;
  const pauseAfter  = 2000;
  const pauseStart  = 500;

  function type() {
    const phrase = phrases[phraseIdx];

    if (!deleting) {
      el.textContent = phrase.substring(0, charIdx + 1);
      charIdx++;
      if (charIdx === phrase.length) {
        deleting = true;
        setTimeout(type, pauseAfter);
        return;
      }
      setTimeout(type, typeSpeed);
    } else {
      el.textContent = phrase.substring(0, charIdx - 1);
      charIdx--;
      if (charIdx === 0) {
        deleting = false;
        phraseIdx = (phraseIdx + 1) % phrases.length;
        setTimeout(type, pauseStart);
        return;
      }
      setTimeout(type, deleteSpeed);
    }
  }

  setTimeout(type, 800);
})();

/* ── Navbar Scroll Effect ────────────────────────────────────── */
(function initNavbar() {
  const navbar = document.getElementById('navbar');
  if (!navbar) return;

  window.addEventListener('scroll', () => {
    navbar.classList.toggle('scrolled', window.scrollY > 60);
  }, { passive: true });

  // Active nav link highlight
  const sections  = document.querySelectorAll('section[id]');
  const navLinks  = document.querySelectorAll('.nav-link');

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        navLinks.forEach(link => link.classList.remove('active'));
        const active = document.querySelector(`.nav-link[href="#${entry.target.id}"]`);
        if (active) active.classList.add('active');
      }
    });
  }, { threshold: 0.4 });

  sections.forEach(s => observer.observe(s));
})();

/* ── Mobile Nav Toggle ───────────────────────────────────────── */
(function initMobileNav() {
  const toggle = document.getElementById('navToggle');
  const links  = document.getElementById('navLinks');
  if (!toggle || !links) return;

  toggle.addEventListener('click', () => {
    const open = links.classList.toggle('open');
    toggle.setAttribute('aria-expanded', open);
    document.body.style.overflow = open ? 'hidden' : '';
  });

  links.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      links.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    });
  });

  document.addEventListener('click', e => {
    if (!toggle.contains(e.target) && !links.contains(e.target)) {
      links.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    }
  });
})();

/* ── Scroll Reveal ───────────────────────────────────────────── */
(function initScrollReveal() {
  const revealEls = document.querySelectorAll('.reveal-up, .reveal-left, .reveal-right');

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  revealEls.forEach(el => observer.observe(el));
})();

/* ── Skill Bar Animation ─────────────────────────────────────── */
(function initSkillBars() {
  const fills = document.querySelectorAll('.skill-bar-fill');

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const width = entry.target.getAttribute('data-width');
        entry.target.style.width = width + '%';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.3 });

  fills.forEach(fill => observer.observe(fill));
})();

/* ── Research Card Hover Glow ────────────────────────────────── */
(function initResearchCards() {
  const cards = document.querySelectorAll('.research-card');

  cards.forEach(card => {
    card.addEventListener('mousemove', e => {
      const rect  = card.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top)  / rect.height) * 100;
      card.style.setProperty('--mx', x + '%');
      card.style.setProperty('--my', y + '%');
    });

    // Keyboard accessibility
    card.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        const link = card.querySelector('.research-link');
        if (link) link.click();
      }
    });
  });
})();

/* ── Contact Form ────────────────────────────────────────────── */
(function initContactForm() {
  const btn  = document.getElementById('sendBtn');
  const note = document.getElementById('formNote');
  if (!btn) return;

  btn.addEventListener('click', () => {
    const name  = document.getElementById('contactName')?.value.trim();
    const email = document.getElementById('contactEmail')?.value.trim();
    const msg   = document.getElementById('contactMsg')?.value.trim();

    if (!name || !email || !msg) {
      if (note) {
        note.style.color = '#f59e0b';
        note.textContent = 'Please fill in all fields.';
      }
      return;
    }

    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRe.test(email)) {
      if (note) {
        note.style.color = '#f59e0b';
        note.textContent = 'Please enter a valid email address.';
      }
      return;
    }

    btn.textContent = 'Sending...';
    btn.disabled = true;

    setTimeout(() => {
      if (note) {
        note.style.color = '#00ff9d';
        note.textContent = '✓ Message sent! I\'ll get back to you soon.';
      }
      btn.textContent = 'Send Message';
      btn.disabled = false;
      document.getElementById('contactName').value  = '';
      document.getElementById('contactEmail').value = '';
      document.getElementById('contactMsg').value   = '';
    }, 1400);
  });
})();

/* ── Footer Year ─────────────────────────────────────────────── */
(function setFooterYear() {
  const el = document.getElementById('footerYear');
  if (el) el.textContent = new Date().getFullYear();
})();

/* ── Orbital Nodes Animation ─────────────────────────────────── */
(function animateOrbitNodes() {
  const nodes = document.querySelectorAll('.orbit-node');
  if (!nodes.length) return;

  // Counter-rotate nodes to keep them upright while ring spins
  // This is handled purely by CSS positioning, no JS needed
  // But let's add a subtle float animation
  nodes.forEach((node, i) => {
    node.style.animationDelay = (i * 0.3) + 's';
  });
})();

/* ── Smooth Section Highlighting ────────────────────────────── */
(function smoothHighlight() {
  // Add glow to active nav link
  const style = document.createElement('style');
  style.textContent = `.nav-link.active { color: var(--accent-cyan) !important; }
    .nav-link.active::after { width: 100% !important; }`;
  document.head.appendChild(style);
})();

/* ── Tilt Effect on Glass Cards ─────────────────────────────── */
(function initTilt() {
  const cards = document.querySelectorAll('.info-card, .tech-card, .interest-card');

  cards.forEach(card => {
    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const cx = rect.left + rect.width  / 2;
      const cy = rect.top  + rect.height / 2;
      const dx = (e.clientX - cx) / (rect.width  / 2);
      const dy = (e.clientY - cy) / (rect.height / 2);
      const maxTilt = 6;
      card.style.transform = `perspective(600px) rotateX(${-dy * maxTilt}deg) rotateY(${dx * maxTilt}deg) translateY(-4px)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
    });
  });
})();

/* ── Scroll Progress Indicator ──────────────────────────────── */
(function initScrollProgress() {
  const bar = document.createElement('div');
  bar.style.cssText = `
    position: fixed;
    top: 0; left: 0;
    height: 2px;
    background: linear-gradient(90deg, #00d4ff, #7c3aed);
    z-index: 10000;
    width: 0%;
    transition: width 0.1s;
    box-shadow: 0 0 8px rgba(0,212,255,0.6);
  `;
  document.body.appendChild(bar);

  window.addEventListener('scroll', () => {
    const pct = (window.scrollY / (document.documentElement.scrollHeight - window.innerHeight)) * 100;
    bar.style.width = Math.min(pct, 100) + '%';
  }, { passive: true });
})();

/* ── Research Card Dynamic Glow ─────────────────────────────── */
(function researchDynamicGlow() {
  document.querySelectorAll('.research-card').forEach(card => {
    const glow = card.querySelector('.research-glow');
    if (!glow) return;

    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top)  / rect.height) * 100;
      glow.style.background = `radial-gradient(ellipse at ${x}% ${y}%, rgba(0,212,255,0.1), transparent 60%)`;
    });
  });
})();

console.log('%c🧠 Biswajit Chandra Das — AI Portfolio Loaded', 'color: #00d4ff; font-family: monospace; font-size: 14px; font-weight: bold;');
