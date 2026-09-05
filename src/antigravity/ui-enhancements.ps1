function Get-AntigravityUiEnhancementsPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_UI_INSTALLED) {
    return;
  }
  window.__ANTIGRAVITY_PLUS_UI_INSTALLED = true;

  // Keyboard shortcut listener: Ctrl+Shift+R to force toggle RTL on composer/view
  window.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.shiftKey && e.code === 'KeyR') {
      e.preventDefault();
      const current = document.body.getAttribute('data-agy-force-rtl');
      if (current === 'true') {
        document.body.removeAttribute('data-agy-force-rtl');
        console.log('[Antigravity Plus] Forced RTL disabled.');
      } else {
        document.body.setAttribute('data-agy-force-rtl', 'true');
        console.log('[Antigravity Plus] Forced RTL enabled.');
      }
    }
  }, true);

  console.log('[Antigravity Plus] UI Enhancements installed (Ctrl+Shift+R to toggle RTL).');
})();
'@
}
