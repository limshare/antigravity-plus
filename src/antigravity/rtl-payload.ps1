function Get-AntigravityRtlPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_RTL_INSTALLED) {
    return;
  }
  window.__ANTIGRAVITY_PLUS_RTL_INSTALLED = true;

  const RTL_SHARED = window.__AGY_RTL_SHARED || (function () {
    const RTL_RE = /[\u0590-\u05FF\uFB1D-\uFB4F\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/;
    const LTR_RE = /[A-Za-z\u00C0-\u024F]/;
    function classifyDirection(text) {
      if (!text) return null;
      const clean = text.replace(/https?:\/\/[^\s]+/g, '').replace(/`[^`]+`/g, '').replace(/```[\s\S]*?```/g, '').trim();
      for (let i = 0; i < clean.length; i++) {
        if (RTL_RE.test(clean[i])) return 'rtl';
        if (LTR_RE.test(clean[i])) return 'ltr';
      }
      return null;
    }
    return { RTL_RE, LTR_RE, classifyDirection };
  })();

  const STYLE_ID = 'antigravity-plus-rtl-style';

  function injectStyles() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      /* Antigravity Plus RTL Styles */
      [data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        unicode-bidi: plaintext !important;
      }

      [data-agy-rtl="ltr"] {
        direction: ltr !important;
        text-align: left !important;
        unicode-bidi: isolate !important;
      }

      /* Keep technical & code islands strictly LTR */
      code, pre, kbd, samp, .cm-editor, .monaco-editor, [data-language], [class*="code-"] {
        direction: ltr !important;
        text-align: left !important;
        unicode-bidi: isolate !important;
      }

      /* Inline code inside RTL sentences */
      [data-agy-rtl="rtl"] code,
      [data-agy-rtl="rtl"] kbd,
      [data-agy-rtl="rtl"] samp {
        direction: ltr !important;
        display: inline-block;
        unicode-bidi: isolate !important;
        text-align: left !important;
      }

      /* RTL Blockquotes */
      blockquote[data-agy-rtl="rtl"] {
        border-left: 0 !important;
        border-right: 3px solid currentColor !important;
        padding-left: 0 !important;
        padding-right: 1rem !important;
        margin-left: 0 !important;
        margin-right: 0 !important;
      }

      /* RTL Ordered and Unordered lists */
      ol[data-agy-rtl="rtl"],
      ul[data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        padding-left: 0 !important;
        padding-right: 1.5rem !important;
        list-style-position: outside !important;
      }

      li[data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      /* Task checkboxes in RTL lists */
      li[data-agy-rtl="rtl"] > input[type="checkbox"] {
        margin-left: 0.5rem !important;
        margin-right: 0 !important;
      }

      /* Tables */
      th[data-agy-rtl="rtl"],
      td[data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      /* Prompt Composer */
      [contenteditable="true"][data-agy-composer-rtl="rtl"],
      textarea[data-agy-composer-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        unicode-bidi: plaintext !important;
      }

      /* Antigravity Plus status indicator */
      #antigravity-plus-indicator {
        position: fixed;
        bottom: 8px;
        right: 12px;
        font-size: 11px;
        padding: 2px 8px;
        border-radius: 9999px;
        background: rgba(16, 185, 129, 0.15);
        color: #10b981;
        border: 1px solid rgba(16, 185, 129, 0.3);
        z-index: 999999;
        pointer-events: none;
        font-family: ui-sans-serif, system-ui, sans-serif;
        font-weight: 500;
        letter-spacing: 0.025em;
        opacity: 0.85;
        transition: opacity 0.2s ease;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  function addIndicator() {
    if (document.getElementById('antigravity-plus-indicator')) return;
    const badge = document.createElement('div');
    badge.id = 'antigravity-plus-indicator';
    badge.textContent = 'Plus RTL';
    document.body.appendChild(badge);
  }

  const TEXT_TAGS = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'LI', 'BLOCKQUOTE', 'TH', 'TD'];
  const EXCLUDE_TAGS = ['PRE', 'CODE', 'KBD', 'SAMP', 'SCRIPT', 'STYLE', 'SVG', 'INPUT', 'BUTTON'];

  function processElement(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) return;
    if (EXCLUDE_TAGS.includes(element.tagName)) return;
    if (element.closest('pre, code, .cm-editor, .monaco-editor')) return;

    if (TEXT_TAGS.includes(element.tagName)) {
      const text = element.innerText;
      if (!text || text.length < 2) return;

      const dir = RTL_SHARED.classifyDirection(text);
      if (dir === 'rtl') {
        if (element.getAttribute('data-agy-rtl') !== 'rtl') {
          element.setAttribute('data-agy-rtl', 'rtl');
        }
      } else if (dir === 'ltr') {
        if (element.getAttribute('data-agy-rtl') === 'rtl') {
          element.removeAttribute('data-agy-rtl');
        }
      }
      return;
    }

    // Sidebar titles and labels
    if (element.tagName === 'A' || element.getAttribute('role') === 'button') {
      const ariaLabel = element.getAttribute('aria-label') || element.innerText;
      if (ariaLabel && RTL_SHARED.classifyDirection(ariaLabel) === 'rtl') {
        if (element.getAttribute('data-agy-rtl') !== 'rtl') {
          element.setAttribute('data-agy-rtl', 'rtl');
        }
      }
    }
  }

  function hookComposer() {
    const composers = document.querySelectorAll('[contenteditable="true"], textarea');
    composers.forEach((composer) => {
      if (composer.__agy_composer_hooked) return;
      composer.__agy_composer_hooked = true;

      const updateComposerDirection = () => {
        const text = composer.innerText || composer.value || '';
        const dir = RTL_SHARED.classifyDirection(text);
        if (dir === 'rtl') {
          composer.setAttribute('data-agy-composer-rtl', 'rtl');
        } else if (dir === 'ltr') {
          composer.removeAttribute('data-agy-composer-rtl');
        } else {
          // When empty, remove attribute
          if (!text.trim()) {
            composer.removeAttribute('data-agy-composer-rtl');
          }
        }
      };

      composer.addEventListener('input', updateComposerDirection, { passive: true });
      composer.addEventListener('keyup', updateComposerDirection, { passive: true });
      updateComposerDirection();
    });
  }

  function processTree(root) {
    if (!root) return;
    const candidates = root.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote, th, td, nav a, aside a, [role="navigation"] a');
    for (let i = 0; i < candidates.length; i++) {
      processElement(candidates[i]);
    }
    hookComposer();
  }

  // Initial pass
  injectStyles();
  processTree(document.body);
  addIndicator();

  // MutationObserver with debounce for high-volume streaming
  let debounceTimer = null;
  const observer = new MutationObserver((mutations) => {
    if (debounceTimer) return;
    debounceTimer = setTimeout(() => {
      debounceTimer = null;
      processTree(document.body);
    }, 60);
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

  window.__ANTIGRAVITY_PLUS_OBSERVER = observer;
  console.log('[Antigravity Plus] RTL and enhancements active.');
})();
'@
}
