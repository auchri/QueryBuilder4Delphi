// Native anchor navigation keeps URLs, keyboard access and browser history intact.
// CSS provides smooth scrolling, with an immediate fallback for reduced motion.
const documentationNav = document.querySelector('.sidebar nav');
const navFrame = document.querySelector('.nav-scroll');
const advanced = document.querySelector('.advanced-nav');
const mobile = matchMedia('(max-width: 680px)');
let navScheduled = false;
function updateOverflow() {
  navScheduled = false;
  navFrame.classList.toggle('has-more', mobile.matches && documentationNav.scrollWidth - documentationNav.clientWidth - documentationNav.scrollLeft > 2);
}
function scheduleOverflow() {
  if (!navScheduled) { navScheduled = true; requestAnimationFrame(updateOverflow); }
}
function revealActive() {
  if (mobile.matches) {
    const active = documentationNav.querySelector('[aria-current="page"]');
    if (active) documentationNav.scrollLeft += active.getBoundingClientRect().left - documentationNav.getBoundingClientRect().left - (documentationNav.clientWidth - active.offsetWidth) / 2;
  }
  scheduleOverflow();
}
advanced.addEventListener('toggle', () => {
  advanced.querySelector('summary').setAttribute('aria-expanded', String(advanced.open));
  scheduleOverflow();
});
documentationNav.addEventListener('scroll', scheduleOverflow, { passive: true });
new ResizeObserver(scheduleOverflow).observe(documentationNav);
mobile.addEventListener('change', revealActive);
window.addEventListener('pageshow', revealActive);
revealActive();

const backToTop = document.querySelector('.back-to-top');
const links = [...document.querySelectorAll('.toc nav a')];
const sections = links.map(link => ({
  link,
  heading: document.getElementById(decodeURIComponent(link.hash.slice(1))),
})).filter(section => section.heading);
let scheduled = false;

function updateNavigation() {
  scheduled = false;
  backToTop.hidden = window.scrollY < 400;
  const offset = parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop) + 32;
  let current = null;
  for (const section of sections) {
    if (section.heading.getBoundingClientRect().top <= offset) current = section;
    else break;
  }
  // Keep the final section selected when it is too short to reach the header.
  if (window.scrollY > 0 && window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) current = sections.at(-1);
  for (const section of sections) {
    if (section === current) section.link.setAttribute('aria-current', 'location');
    else section.link.removeAttribute('aria-current');
  }
}

window.addEventListener('scroll', () => {
  if (!scheduled) { scheduled = true; requestAnimationFrame(updateNavigation); }
}, { passive: true });
window.addEventListener('resize', updateNavigation);
window.addEventListener('pageshow', updateNavigation);
backToTop.addEventListener('click', () => {
  document.querySelector('.brand').focus({ preventScroll: true });
});
updateNavigation();
