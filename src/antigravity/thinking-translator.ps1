function Get-AntigravityThinkingTranslatorPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_THINKING_TRANSLATOR) {
    try { window.__ANTIGRAVITY_PLUS_THINKING_TRANSLATOR.cleanup(); } catch (e) {}
  }

  const TRANSLATION_CACHE = new Map();
  const PENDING_TRANSLATIONS = new Set();

  // Inject Dedicated Styles
  const STYLE_ID = 'antigravity-plus-thinking-translator-style';
  let styleEl = document.getElementById(STYLE_ID);
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = STYLE_ID;
    (document.head || document.documentElement).appendChild(styleEl);
  }
  styleEl.textContent = `
    .agy-thinking-translated {
      direction: rtl !important;
      text-align: right !important;
      unicode-bidi: isolate !important;
      font-family: inherit;
      line-height: 1.6;
      font-size: 0.875rem;
      word-break: break-word;
      white-space: pre-wrap;
    }
    .agy-thinking-translated p {
      margin-top: 0 !important;
      margin-bottom: 0.5rem !important;
    }
    .agy-thinking-translated p:last-child {
      margin-bottom: 0 !important;
    }
    .agy-thinking-translated code {
      direction: ltr !important;
      unicode-bidi: isolate !important;
      display: inline-block;
      font-family: monospace;
      padding: 0.1em 0.3em;
      border-radius: 4px;
      background: rgba(128, 128, 128, 0.15);
      font-size: 0.9em;
    }
  `;

  function isMostlyHebrew(text) {
    if (!text) return false;
    const hebrewMatches = text.match(/[\u0590-\u05FF]/g) || [];
    const latinMatches = text.match(/[A-Za-z]/g) || [];
    if (hebrewMatches.length === 0) return false;
    return hebrewMatches.length >= latinMatches.length;
  }

  async function translateToHebrew(text) {
    if (!text || !text.trim()) return '';
    const clean = text.trim();
    if (TRANSLATION_CACHE.has(clean)) {
      return TRANSLATION_CACHE.get(clean);
    }

    // Split large text into chunks under 1200 chars to avoid URL length limits
    const paragraphs = clean.split(/\n\n+/);
    const chunks = [];
    let current = '';

    for (const p of paragraphs) {
      if ((current + '\n\n' + p).length > 1200) {
        if (current) chunks.push(current);
        current = p;
      } else {
        current = current ? current + '\n\n' + p : p;
      }
    }
    if (current) chunks.push(current);

    try {
      const results = [];
      for (const chunk of chunks) {
        const url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=iw&dt=t&q=' + encodeURIComponent(chunk);
        const res = await fetch(url);
        if (!res.ok) throw new Error('Translation fetch failed: ' + res.status);
        const data = await res.json();
        const translatedPart = (data && data[0]) ? data[0].map(item => item[0]).join('') : chunk;
        results.push(translatedPart);
      }
      const fullTranslation = results.join('\n\n');
      TRANSLATION_CACHE.set(clean, fullTranslation);
      return fullTranslation;
    } catch (err) {
      console.warn('[Antigravity Plus] Thinking translation error:', err);
      return clean;
    }
  }

  function extractCleanThinkingText(wrapper) {
    if (!wrapper) return '';
    try {
      const clone = wrapper.cloneNode(true);
      const toRemove = clone.querySelectorAll('style, script, svg, [data-testid*="toggle"], .agy-thinking-translate-toggle');
      toRemove.forEach(el => el.remove());
      let text = (clone.innerText || clone.textContent || '').trim();
      // Cleanly remove any embedded CSS rules, remark-alert comments or style blocks
      text = text.replace(/\/\*[\s\S]*?\*\//g, '');
      text = text.replace(/@media[^{]+\{[\s\S]*?\}\s*\}/g, '');
      text = text.replace(/\.markdown-alert[^{]*\{[\s\S]*?\}/g, '');
      text = text.replace(/div:has\(>\s*table\)[^{]*\{[\s\S]*?\}/g, '');
      text = text.replace(/\.md-table[^{]*\{[\s\S]*?\}/g, '');
      return text.trim();
    } catch (e) {
      return (wrapper.innerText || wrapper.textContent || '').trim();
    }
  }

  async function processThinkingTrigger(trigger) {
    if (!trigger || !document.body.contains(trigger)) return;

    const container = trigger.nextElementSibling;
    if (!container) return;

    const scrollable = container.querySelector('.overflow-y-auto') || container;
    // Find the original react content container
    const originalWrapper = Array.from(scrollable.children).find(
      child => !child.classList.contains('agy-thinking-translated')
    );
    if (!originalWrapper) return;

    const rawText = extractCleanThinkingText(originalWrapper);
    if (!rawText || rawText.length < 5) return;

    // If text is already predominantly Hebrew, skip auto-translation
    if (isMostlyHebrew(rawText)) {
      return;
    }

    const textHash = 'hash_' + rawText.length + '_' + rawText.slice(0, 30);
    const prevHash = trigger.getAttribute('data-agy-thinking-hash');

    let translatedEl = scrollable.querySelector('.agy-thinking-translated');

    if (prevHash === textHash && translatedEl) {
      return; // Already up-to-date
    }

    if (PENDING_TRANSLATIONS.has(textHash)) {
      return;
    }

    PENDING_TRANSLATIONS.add(textHash);

    try {
      const translatedText = await translateToHebrew(rawText);
      PENDING_TRANSLATIONS.delete(textHash);

      if (!document.body.contains(trigger) || !document.body.contains(scrollable)) return;

      trigger.setAttribute('data-agy-thinking-hash', textHash);

      if (!translatedEl) {
        translatedEl = document.createElement('div');
        translatedEl.className = 'agy-thinking-translated leading-relaxed select-text text-sm flex flex-col gap-2 pl-2 text-secondary-foreground';
        scrollable.appendChild(translatedEl);
      }

      // Format paragraphs and code tokens
      const formattedHtml = translatedText
        .split(/\n\n+/)
        .map(paragraph => {
          const escaped = paragraph
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
          const withCode = escaped.replace(/`([^`]+)`/g, '<code>$1</code>');
          return `<p>${withCode}</p>`;
        })
        .join('');

      translatedEl.innerHTML = formattedHtml;

      // Always show translated Hebrew, hide original English
      translatedEl.style.display = 'block';
      originalWrapper.style.display = 'none';
    } catch (e) {
      PENDING_TRANSLATIONS.delete(textHash);
      console.error('[Antigravity Plus] Failed to process thinking translation:', e);
    }
  }

  function checkAllThinkingElements(root = document) {
    const triggers = root.querySelectorAll('[data-testid="thinking-collapsible-trigger"]');
    for (const trigger of triggers) {
      processThinkingTrigger(trigger);
    }
  }

  // Initial check
  checkAllThinkingElements();

  // Polling interval & MutationObserver for continuous coverage
  const intervalId = setInterval(() => {
    checkAllThinkingElements();
  }, 1000);

  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'childList') {
        for (const node of m.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            if (node.matches && node.matches('[data-testid="thinking-collapsible-trigger"]')) {
              processThinkingTrigger(node);
            } else if (node.querySelectorAll) {
              const innerTriggers = node.querySelectorAll('[data-testid="thinking-collapsible-trigger"]');
              for (const it of innerTriggers) processThinkingTrigger(it);
            }
          }
        }
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  window.__ANTIGRAVITY_PLUS_THINKING_TRANSLATOR = {
    cleanup: function () {
      clearInterval(intervalId);
      observer.disconnect();
    },
    translateToHebrew,
    processThinkingTrigger,
    checkAllThinkingElements
  };
})();
'@
}
