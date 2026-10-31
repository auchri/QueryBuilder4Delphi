// Native anchor navigation keeps URLs, keyboard access and browser history intact.
// CSS provides smooth scrolling, with an immediate fallback for reduced motion.
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
