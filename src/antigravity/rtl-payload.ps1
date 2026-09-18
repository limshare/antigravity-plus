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
    function firstStrongDirection(text) {
      const value = String(text || '');
      for (let i = 0; i < value.length;) {
        const cp = value.codePointAt(i);
        if (isRtlCodePoint(cp)) return 'rtl';
        if ((cp >= 0x41 && cp <= 0x5a) || (cp >= 0x61 && cp <= 0x7a)) return 'ltr';
        i += cp > 0xffff ? 2 : 1;
      }
      return null;
    }
    function lastStrongDirection(text) {
      const value = String(text || '');
      let last = null;
      for (let i = 0; i < value.length;) {
        const cp = value.codePointAt(i);
        if (isRtlCodePoint(cp)) last = 'rtl';
        else if ((cp >= 0x41 && cp <= 0x5a) || (cp >= 0x61 && cp <= 0x7a)) last = 'ltr';
        i += cp > 0xffff ? 2 : 1;
      }
      return last;
    }
    function proseDirection(text) {
      const value = String(text || '');
      if (hasRtlCodePoint(value)) return 'rtl';
      return firstStrongDirection(value);
    }
    function hasMixedTerminalLtrTail(text) {
      const value = String(text || '');
      return firstStrongDirection(value) === 'rtl'
        && hasRtlCodePoint(value)
        && lastStrongDirection(value) === 'ltr';
    }
    function stripCodeAndUrls(text) {
      if (!text) return '';
      return String(text)
        .replace(/https?:\/\/[^\s]+/g, '')
        .replace(/`[^`]+`/g, '')
        .replace(/```[\s\S]*?```/g, '')
        .trim();
    }
    function stripDiagnosticPrefix(text) {
      const normalized = String(text || '').replace(/\s+/g, ' ').trim();
      const match = normalized.match(/^([A-Z]\d{1,3}|\d{1,3})\.\s*([^:\n]{1,80}):\s*/u);
      if (match && !hasRtlCodePoint(match[2])) {
        return normalized.slice(match[0].length).trim();
      }
      return normalized;
    }
    function getMeaningfulText(input, skipSelector) {
      if (!input) return '';
      if (typeof input === 'string') return stripDiagnosticPrefix(stripCodeAndUrls(input));
      const clone = input.cloneNode(true);
      if (skipSelector) {
        for (const technical of clone.querySelectorAll(skipSelector)) technical.remove();
      }
      return stripDiagnosticPrefix(stripCodeAndUrls(clone.innerText || clone.textContent || ''));
    }
    function classifyDirection(text) {
      const clean = getMeaningfulText(text);
      if (!clean) return null;
      if (hasRtlCodePoint(clean)) return 'rtl';
      return 'ltr';
    }
    function classifyProseDirection(input, skipSelector) {
      const clean = getMeaningfulText(input, skipSelector);
      if (!clean) return null;
      return proseDirection(clean) || classifyDirection(clean);
    }
    function cellDirection(text) {
      if (hasRtlCodePoint(text)) return 'rtl';
      return null;
    }
    function tableDirectionFromCells(headerDirs, firstColDirs) {
      if (headerDirs?.[0] === 'rtl' || firstColDirs?.[0] === 'rtl') return 'rtl';
      return null;
    }
    return { RTL_RE, LTR_RE, hasRtlCodePoint, hasMixedTerminalLtrTail, getMeaningfulText, proseDirection, classifyDirection, classifyProseDirection, cellDirection, tableDirectionFromCells };
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
      [data-agy-rtl="rtl"], [dir="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        unicode-bidi: isolate !important;
      }

      [data-agy-rtl="ltr"] {
        direction: ltr !important;
        text-align: left !important;
        unicode-bidi: isolate !important;
      }

      [data-agy-rtl-ltr-tail="true"] {
        direction: ltr !important;
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
      [data-agy-rtl="rtl"] samp,
      [dir="rtl"] code,
      [dir="rtl"] kbd,
      [dir="rtl"] samp {
        direction: ltr !important;
        display: inline-block;
        unicode-bidi: isolate !important;
        text-align: left !important;
      }

      /* RTL Blockquotes */
      blockquote[data-agy-rtl="rtl"],
      blockquote[dir="rtl"] {
        border-left: 0 !important;
        border-right: 3px solid currentColor !important;
        padding-left: 0 !important;
        padding-right: 1rem !important;
        margin-left: 0 !important;
        margin-right: 0 !important;
      }

      /* RTL Ordered and Unordered lists */
      ol[data-agy-rtl="rtl"],
      ol[dir="rtl"],
      ul[data-agy-rtl="rtl"],
      ul[dir="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        padding-left: 0 !important;
        padding-right: 1.5rem !important;
        list-style-position: outside !important;
      }

      li[data-agy-rtl="rtl"],
      li[dir="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      /* Task checkboxes in RTL lists */
      li[data-agy-rtl="rtl"] > input[type="checkbox"],
      li[dir="rtl"] > input[type="checkbox"] {
        margin-left: 0.5rem !important;
        margin-right: 0 !important;
      }

      /* Tables */
      table[data-agy-rtl="rtl"],
      table[dir="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      th[data-agy-rtl="rtl"],
      th[dir="rtl"],
      td[data-agy-rtl="rtl"],
      td[dir="rtl"] {
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

      /* Artifact Cards & Line Clamps */
      .artifact-card[data-agy-rtl="rtl"],
      [class*="artifact-card"][data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      .artifact-card[data-agy-rtl="rtl"] > button[dir="ltr"],
      [class*="artifact-card"][data-agy-rtl="rtl"] > button[dir="ltr"] {
        direction: ltr !important;
        text-align: left !important;
      }

      .artifact-card span[data-agy-rtl="rtl"],
      .artifact-card [class*="line-clamp"][data-agy-rtl="rtl"],
      [class*="line-clamp"][data-agy-rtl="rtl"] {
        direction: rtl !important;
        text-align: right !important;
        unicode-bidi: isolate !important;
        width: 100% !important;
      }
    `;

    const oldIndicator = document.getElementById('antigravity-plus-indicator');
    if (oldIndicator) oldIndicator.remove();
  }

  const MIXED_LTR_TAIL_ATTRIBUTE = 'data-agy-rtl-ltr-tail';
  const LIST_CONTAINER_SELECTOR = 'ol, ul';
  const LIST_ITEM_SELECTOR = 'li';

  function cleanupOwnedDirection(element) {
    if (!element || !element.hasAttribute('data-agy-rtl')) return;
    element.removeAttribute('data-agy-rtl');
    element.removeAttribute('dir');
    element.style.textAlign = '';
    element.style.unicodeBidi = '';
  }

  function setOwnedDirection(element, direction, marker, unicodeBidi, forceLtr) {
    const shouldApply = direction === 'rtl' || (direction === 'ltr' && forceLtr);
    if (!shouldApply) {
      cleanupOwnedDirection(element);
      return;
    }

    if (element.getAttribute('dir') !== direction) {
      element.setAttribute('dir', direction);
    }
    if (element.getAttribute('data-agy-rtl') !== marker) {
      element.setAttribute('data-agy-rtl', marker);
    }
    const textAlign = direction === 'rtl' ? 'right' : 'left';
    if (element.style.textAlign !== textAlign) {
      element.style.textAlign = textAlign;
    }
    if (element.style.unicodeBidi !== (unicodeBidi || 'isolate')) {
      element.style.unicodeBidi = unicodeBidi || 'isolate';
    }
  }

  function applyBlockDirection(element, direction, options) {
    const forceLtr = Boolean(options && options.forceLtr);
    if (direction === 'rtl') {
      setOwnedDirection(element, 'rtl', 'rtl', 'isolate', false);
    } else if (direction === 'ltr' && forceLtr) {
      setOwnedDirection(element, 'ltr', 'ltr', 'isolate', true);
    } else {
      cleanupOwnedDirection(element);
    }
  }

  function unwrapMixedLtrTails(root) {
    for (const wrapper of root.querySelectorAll('[' + MIXED_LTR_TAIL_ATTRIBUTE + '="true"]')) {
      const parent = wrapper.parentNode;
      if (!parent) continue;
      while (wrapper.firstChild) parent.insertBefore(wrapper.firstChild, wrapper);
      wrapper.remove();
    }
  }

  function getTrailingTextNode(root) {
    const walker = document.createTreeWalker(root, 4 /* NodeFilter.SHOW_TEXT */);
    let current = walker.nextNode();
    let last = null;
    while (current) {
      const parent = current.parentElement;
      if (current.textContent?.trim()
          && /[A-Za-z]/u.test(current.textContent)
          && parent
          && !parent.closest('pre, code, kbd, samp')
          && !parent.closest('[' + MIXED_LTR_TAIL_ATTRIBUTE + '="true"]')) {
        last = current;
      }
      current = walker.nextNode();
    }
    return last;
  }

  function ensureMixedLtrTail(element) {
    const normalized = RTL_SHARED.getMeaningfulText ? RTL_SHARED.getMeaningfulText(element) : (element.innerText || element.textContent || '');
    const needsTailIsolation = RTL_SHARED.hasMixedTerminalLtrTail ? RTL_SHARED.hasMixedTerminalLtrTail(normalized) : false;
    const existing = element.querySelector('[' + MIXED_LTR_TAIL_ATTRIBUTE + '="true"]');
    if (!needsTailIsolation) {
      if (existing) unwrapMixedLtrTails(element);
      return;
    }
    if (existing) return;

    const textNode = getTrailingTextNode(element);
    if (!textNode) return;

    const match = /[A-Za-z][A-Za-z0-9._/?#:@%+~=-]*[.!?,;:)\]}]*(?=[\s\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]*$)/u.exec(textNode.textContent || '');
    if (!match) return;

    const fullTail = match[0];
    const punctuationMatch = /[.!?,;:)\]}]+$/u.exec(fullTail);
    const punctuation = punctuationMatch?.[0] || '';
    const wordText = punctuation ? fullTail.slice(0, -punctuation.length) : fullTail;
    if (!wordText) return;

    const tail = match.index > 0 ? textNode.splitText(match.index) : textNode;
    if (wordText.length < (tail.textContent || '').length) {
      tail.splitText(wordText.length);
    }
    const wrapper = element.ownerDocument.createElement('span');
    wrapper.setAttribute(MIXED_LTR_TAIL_ATTRIBUTE, 'true');
    wrapper.setAttribute('dir', 'ltr');
    wrapper.style.unicodeBidi = 'isolate';
    tail.parentNode.insertBefore(wrapper, tail);
    wrapper.appendChild(tail);
  }

  function getListItemOwnText(item) {
    const clone = item.cloneNode(true);
    for (const nested of clone.querySelectorAll(LIST_CONTAINER_SELECTOR)) {
      nested.remove();
    }
    return RTL_SHARED.getMeaningfulText ? RTL_SHARED.getMeaningfulText(clone, 'code, kbd, samp') : (clone.innerText || clone.textContent || '');
  }

  function processLists(root) {
    for (const list of root.querySelectorAll(LIST_CONTAINER_SELECTOR)) {
      if (list.closest('pre, code, kbd, samp, .cm-editor, .monaco-editor, [contenteditable="false"]')) continue;
      const listText = Array.from(list.querySelectorAll(':scope > ' + LIST_ITEM_SELECTOR))
        .map((item) => getListItemOwnText(item))
        .join(' ');
      const listDirection = (RTL_SHARED.classifyProseDirection ? RTL_SHARED.classifyProseDirection(listText || list) : RTL_SHARED.classifyDirection(listText || list)) || 'ltr';
      
      applyBlockDirection(list, listDirection);

      for (const item of list.querySelectorAll(':scope > ' + LIST_ITEM_SELECTOR)) {
        if (item.closest('pre, code, kbd, samp, [contenteditable="false"]')) continue;
        const itemOwnText = getListItemOwnText(item);
        const itemDirection = (RTL_SHARED.classifyProseDirection ? RTL_SHARED.classifyProseDirection(itemOwnText) : RTL_SHARED.classifyDirection(itemOwnText)) || listDirection;
        ensureMixedLtrTail(item);
        applyBlockDirection(item, itemDirection, { forceLtr: listDirection === 'rtl' });
        processInlineTechnicalIslands(item);
      }
    }
  }

  function processArtifactCards(root) {
    if (!root) return;
    const cards = root.querySelectorAll('.artifact-card, [class*="artifact-card"]');
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card.closest('pre, code, .cm-editor, .monaco-editor, [contenteditable="false"]')) continue;

      const summary = card.querySelector('.line-clamp-3, [class*="line-clamp"]') || Array.from(card.children).find(c => c.tagName === 'SPAN');
      const button = card.querySelector('button');

      const summaryText = summary ? (RTL_SHARED.getMeaningfulText ? RTL_SHARED.getMeaningfulText(summary) : (summary.innerText || summary.textContent || '')) : '';
      const summaryDir = summaryText ? (RTL_SHARED.classifyProseDirection ? RTL_SHARED.classifyProseDirection(summaryText) : RTL_SHARED.classifyDirection(summaryText)) : 'neutral';

      const buttonText = button ? (RTL_SHARED.getMeaningfulText ? RTL_SHARED.getMeaningfulText(button) : (button.innerText || button.textContent || '')) : '';
      const buttonDir = buttonText ? RTL_SHARED.classifyDirection(buttonText) : 'neutral';

      if (summaryDir === 'rtl') {
        applyBlockDirection(card, 'rtl');

        if (summary) {
          ensureMixedLtrTail(summary);
          applyBlockDirection(summary, 'rtl');
          processInlineTechnicalIslands(summary);
        }

        if (button) {
          if (buttonDir === 'ltr') {
            applyBlockDirection(button, 'ltr', { forceLtr: true });
          } else if (buttonDir === 'rtl') {
            applyBlockDirection(button, 'rtl');
          }
        }
      } else if (summaryDir === 'ltr') {
        if (card.getAttribute('data-agy-rtl') === 'rtl') {
          cleanupOwnedDirection(card);
          if (summary) {
            cleanupOwnedDirection(summary);
            unwrapMixedLtrTails(summary);
          }
          if (button) {
            cleanupOwnedDirection(button);
          }
        }
      }
    }
  }

  function processInlineTechnicalIslands(root) {
    if (!root) return;
    for (const technical of root.querySelectorAll('code, kbd, samp')) {
      if (technical.closest('pre')) continue;
      if (technical.getAttribute('dir') !== 'ltr') {
        technical.setAttribute('dir', 'ltr');
      }
    }
  }

  const TEXT_TAGS = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE', 'TH', 'TD', 'FIGCAPTION'];
  const EXCLUDE_TAGS = ['PRE', 'CODE', 'KBD', 'SAMP', 'SCRIPT', 'STYLE', 'SVG', 'INPUT'];

  function processElement(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) return;
    if (EXCLUDE_TAGS.includes(element.tagName)) return;
    if (element.closest('pre, code, .cm-editor, .monaco-editor, [data-antigravity-plus-context-badge], [data-gemini-plus-top-badge], [data-codex-plus-context-badge]')) return;
    // worked-for-collapsible is managed exclusively by ui-enhancements (always LTR)
    if (element.closest('[data-testid="worked-for-collapsible"]')) return;
    if (element.tagName === 'LI' || element.tagName === 'OL' || element.tagName === 'UL') return;

    // Direct text blocks, user message bubbles, articles, tooltips, choice options, line clamps
    const isSpecialBlock = element.hasAttribute('data-quotable')
      || element.getAttribute('data-testid') === 'user-input-step'
      || element.matches?.('[role="tooltip"], [role="article"], [role="radio"], [role="checkbox"], .line-clamp-3, [class*="line-clamp"]');

    if (TEXT_TAGS.includes(element.tagName) || isSpecialBlock) {
      const dir = RTL_SHARED.classifyProseDirection ? RTL_SHARED.classifyProseDirection(element) : RTL_SHARED.classifyDirection(element);
      if (dir === 'rtl') {
        ensureMixedLtrTail(element);
        applyBlockDirection(element, 'rtl');
        processInlineTechnicalIslands(element);
      } else if (dir === 'ltr') {
        applyBlockDirection(element, null);
      }
      return;
    }

    // Sidebar titles and labels
    if (element.tagName === 'A' || element.getAttribute('role') === 'button' || element.matches?.('button[data-project-card="true"]')) {
      const ariaLabel = element.getAttribute('aria-label') || element.innerText || '';
      if (ariaLabel && RTL_SHARED.classifyDirection(ariaLabel) === 'rtl') {
        applyBlockDirection(element, 'rtl');
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
      applyBlockDirection(table, 'rtl');
    } else if (tableDir === 'ltr') {
      applyBlockDirection(table, null);
    }
    processInlineTechnicalIslands(table);
  }

  function hookComposer() {
    const composers = document.querySelectorAll('[contenteditable="true"], textarea');
    composers.forEach((composer) => {
      if (composer.__agy_composer_hooked) return;
      composer.__agy_composer_hooked = true;

      // Native browser bidi support
      if (composer.getAttribute('dir') !== 'auto') {
        composer.setAttribute('dir', 'auto');
      }
      if (composer.style.textAlign !== 'start') {
        composer.style.textAlign = 'start';
      }
      if (composer.style.unicodeBidi !== 'plaintext') {
        composer.style.unicodeBidi = 'plaintext';
      }

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

  function runRtlSelfCheck() {
    const mount = document.body || document.documentElement;
    const result = { ok: false, checkedAt: new Date().toISOString() };
    if (!mount) return result;
    const probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;left:-10000px;top:-10000px;visibility:hidden;';
    probe.innerHTML = '<ol><li>1. בממשק המשתמש (UI):</li></ol><div class="artifact-card"><button><span>Walkthrough</span></button><span class="line-clamp-3">תוכנית מימוש להוספת אקורדיון.</span></div>';
    mount.appendChild(probe);
    try {
      processLists(probe);
      processArtifactCards(probe);
      const list = probe.querySelector('ol');
      const item = probe.querySelector('li');
      const card = probe.querySelector('.artifact-card');
      const summary = probe.querySelector('.line-clamp-3');
      const btn = probe.querySelector('button');
      result.listRtl = list?.getAttribute('dir') === 'rtl';
      result.itemRtl = item?.getAttribute('dir') === 'rtl';
      result.cardRtl = card?.getAttribute('dir') === 'rtl';
      result.summaryRtl = summary?.getAttribute('dir') === 'rtl';
      result.btnLtr = btn?.getAttribute('dir') === 'ltr';
      result.ok = Boolean(result.listRtl && result.itemRtl && result.cardRtl && result.summaryRtl && result.btnLtr);
    } catch (e) {
      result.error = String(e?.message || e);
    } finally {
      probe.remove();
    }
    window.__ANTIGRAVITY_PLUS_RTL_SELF_CHECK = result;
    return result;
  }

  function processTree(root) {
    if (!root) return;
    const tables = root.querySelectorAll('table');
    for (let i = 0; i < tables.length; i++) {
      processTable(tables[i]);
    }
    processLists(root);
    processArtifactCards(root);
    const candidates = root.querySelectorAll('p, h1, h2, h3, h4, h5, h6, blockquote, th, td, figcaption, [data-quotable="true"], [data-testid="user-input-step"], [role="tooltip"], [role="article"], [role="radio"], [role="checkbox"], .line-clamp-3, [class*="line-clamp"], nav a, aside a, [role="navigation"] a');
    for (let i = 0; i < candidates.length; i++) {
      processElement(candidates[i]);
    }
    hookComposer();
  }

  // Initial pass
  injectStyles();
  processTree(document.body);
  runRtlSelfCheck();

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
