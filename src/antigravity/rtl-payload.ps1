function Get-AntigravityRtlPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_RTL_INSTALLED) {
    // Already running - refresh styles
    const oldStyle = document.getElementById('antigravity-plus-rtl-style');
    if (oldStyle) oldStyle.remove();
  }
  window.__ANTIGRAVITY_PLUS_RTL_INSTALLED = true;

  const RTL_SHARED = window.__AGY_RTL_SHARED || (function () {
    const RTL_RE = /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g;
    const LTR_RE = /[A-Za-z\u00C0-\u024F]/g;
    const RTL_CODE_POINT_RANGES = [
      [0x0590, 0x05ff], [0x0600, 0x06ff], [0x0700, 0x074f], [0x0750, 0x077f],
      [0x0780, 0x07bf], [0x07c0, 0x07ff], [0x0800, 0x083f], [0x0840, 0x085f],
      [0x0860, 0x086f], [0x0870, 0x089f], [0x08a0, 0x08ff], [0xfb1d, 0xfb4f],
      [0xfb50, 0xfdff], [0xfe70, 0xfeff], [0x10800, 0x1083f], [0x10840, 0x1085f],
      [0x10a00, 0x10a5f], [0x10e60, 0x10e7f], [0x1e800, 0x1e8df], [0x1e900, 0x1e95f],
      [0x1ee00, 0x1eeff]
    ];
    function isRtlCodePoint(cp) {
      for (const [start, end] of RTL_CODE_POINT_RANGES) {
        if (cp >= start && cp <= end) return true;
      }
      return false;
    }
    function hasRtlCodePoint(text) {
      const value = String(text || '');
      for (let i = 0; i < value.length;) {
        const cp = value.codePointAt(i);
        if (isRtlCodePoint(cp)) return true;
        i += cp > 0xffff ? 2 : 1;
      }
      return false;
    }
    function classifyDirection(text) {
      if (!text) return null;
      const clean = String(text).replace(/https?:\/\/[^\s]+/g, '').replace(/`[^`]+`/g, '').replace(/```[\s\S]*?```/g, '').trim();
      if (!clean) return null;
      if (hasRtlCodePoint(clean)) return 'rtl';
      return 'ltr';
    }
    function cellDirection(text) {
      if (hasRtlCodePoint(text)) return 'rtl';
      return null;
    }
    function tableDirectionFromCells(headerDirs, firstColDirs) {
      if (headerDirs?.[0] === 'rtl' || firstColDirs?.[0] === 'rtl') return 'rtl';
      return null;
    }
    return { RTL_RE, LTR_RE, hasRtlCodePoint, classifyDirection, cellDirection, tableDirectionFromCells };
  })();

  const STYLE_ID = 'antigravity-plus-rtl-style';

  function injectStyles() {
    let style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = `
      /* Antigravity Plus RTL Styles */
      [data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        unicode-bidi: isolate !important;
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
      table[data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

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
        unicode-bidi: isolate !important;
      }
    `;

    const oldIndicator = document.getElementById('antigravity-plus-indicator');
    if (oldIndicator) oldIndicator.remove();
  }

  const TEXT_TAGS = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'LI', 'BLOCKQUOTE', 'TH', 'TD'];
  const EXCLUDE_TAGS = ['PRE', 'CODE', 'KBD', 'SAMP', 'SCRIPT', 'STYLE', 'SVG', 'INPUT', 'BUTTON'];

  function processElement(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) return;
    if (EXCLUDE_TAGS.includes(element.tagName)) return;
    if (element.closest('pre, code, .cm-editor, .monaco-editor, [data-antigravity-plus-context-badge], [data-gemini-plus-top-badge], [data-codex-plus-context-badge]')) return;

    if (TEXT_TAGS.includes(element.tagName)) {
      const text = element.innerText || element.textContent || '';
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
      const ariaLabel = element.getAttribute('aria-label') || element.innerText || '';
      if (ariaLabel && RTL_SHARED.classifyDirection(ariaLabel) === 'rtl') {
        if (element.getAttribute('data-agy-rtl') !== 'rtl') {
          element.setAttribute('data-agy-rtl', 'rtl');
        }
      }
    }
  }

  function processTable(table) {
    if (!table || table.nodeType !== Node.ELEMENT_NODE) return;
    if (!RTL_SHARED.tableDirectionFromCells) return;

    const headerCells = Array.from(table.querySelectorAll('thead th, thead td, tr:first-child th'));
    const firstColCells = Array.from(table.querySelectorAll('tbody tr td:first-child, tr td:first-child'));

    const headerDirs = headerCells.map(c => RTL_SHARED.cellDirection ? RTL_SHARED.cellDirection(c.innerText || c.textContent) : RTL_SHARED.classifyDirection(c.innerText || c.textContent));
    const colDirs = firstColCells.map(c => RTL_SHARED.cellDirection ? RTL_SHARED.cellDirection(c.innerText || c.textContent) : RTL_SHARED.classifyDirection(c.innerText || c.textContent));

    const tableDir = RTL_SHARED.tableDirectionFromCells(headerDirs, colDirs);
    if (tableDir === 'rtl') {
      if (table.getAttribute('data-agy-rtl') !== 'rtl') {
        table.setAttribute('data-agy-rtl', 'rtl');
      }
    } else if (tableDir === 'ltr') {
      if (table.getAttribute('data-agy-rtl') === 'rtl') {
        table.removeAttribute('data-agy-rtl');
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
    const tables = root.querySelectorAll('table');
    for (let i = 0; i < tables.length; i++) {
      processTable(tables[i]);
    }
    const candidates = root.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote, th, td, nav a, aside a, [role="navigation"] a');
    for (let i = 0; i < candidates.length; i++) {
      processElement(candidates[i]);
    }
    hookComposer();
  }

  // Initial pass
  injectStyles();
  processTree(document.body);

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
