function Get-AntigravityUiEnhancementsPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_UI_OBSERVER) {
    try { window.__ANTIGRAVITY_PLUS_UI_OBSERVER.disconnect(); } catch (e) {}
  }
  if (window.__ANTIGRAVITY_PLUS_HEADER_INTERVAL) {
    try { clearInterval(window.__ANTIGRAVITY_PLUS_HEADER_INTERVAL); } catch (e) {}
  }
  if (window.__ANTIGRAVITY_PLUS_SCROLL_INTERVAL) {
    try { clearInterval(window.__ANTIGRAVITY_PLUS_SCROLL_INTERVAL); } catch (e) {}
  }

  // Track the last user prompt turn that has been aligned to the top
  window.__ANTIGRAVITY_PLUS_LAST_ALIGNED_USER_STEP = window.__ANTIGRAVITY_PLUS_LAST_ALIGNED_USER_STEP || null;

  // Keyboard shortcut listener: Ctrl+Shift+R to force toggle RTL on composer/view
  if (!window.__ANTIGRAVITY_PLUS_KEYBINDING_INSTALLED) {
    window.__ANTIGRAVITY_PLUS_KEYBINDING_INSTALLED = true;
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
        return;
      }
    }, true);
  }

  // Styles: Hide notification prompt toast and hide the "Working.." message
  const STYLE_ID = 'antigravity-plus-ui-enhancements-style';
  let style = document.getElementById(STYLE_ID);
  if (!style) {
    style = document.createElement('style');
    style.id = STYLE_ID;
    style.setAttribute('data-antigravity-plus-ui-style', 'true');
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent = `
    /* Hide Notification Preferences prompt toast */
    .toast-viewport .toast-root:not(:has(svg)):has(p):has(button.bg-primary + button.bg-secondary) {
      display: none !important;
    }

    /* Hide the "Working.." / active loading indicator message in the conversation pane */
    [data-testid="agent-loading"],
    .agent-loading {
      display: none !important;
    }

    /* PRE-HIDE command output panels before React renders them visible.
       Any child that is NOT the [role="button"] header inside a command step container
       is hidden by default. Only revealed after the user explicitly toggles it. */
    [data-testid="run-command-step"]:not([data-agy-user-toggled]) > *:not([role="button"]),
    [data-testid="terminal-run-step"]:not([data-agy-user-toggled]) > *:not([role="button"]) {
      display: none !important;
    }

    /* LIVE ACCORDION HEADER:
       Reveal the unified operations container during execution.
       When running, Antigravity adds class 'hidden' to the button.
       We display it as flex plainly (no custom background or border). */
    button[data-testid="worked-for-collapsible"].hidden {
      display: flex !important;
      background: transparent !important;
      border: none !important;
    }

    /* Directional and layout stability for worked-for accordion button */
    button[data-testid="worked-for-collapsible"] {
      direction: ltr !important;
      text-align: left !important;
      unicode-bidi: isolate !important;
    }

    button[data-testid="worked-for-collapsible"] > span.text-secondary-foreground {
      direction: ltr !important;
      text-align: left !important;
      unicode-bidi: isolate !important;
      display: inline-block !important;
    }
  `;

  // Track manual user clicks so user-expanded sections stay expanded,
  // and handle send button / scroll-to-bottom button clicks
  if (!window.__ANTIGRAVITY_PLUS_USER_TOGGLE_LISTENER) {
    window.__ANTIGRAVITY_PLUS_USER_TOGGLE_LISTENER = true;
    document.addEventListener('click', (e) => {
      const target = e.target;
      if (!target || !target.closest) return;

      // 1. Detect scroll to bottom button click (native system arrow)
      const scrollBottomBtn = target.closest(
        'button[aria-label*="bottom" i], button[title*="bottom" i], [data-testid*="scroll-to-bottom"], [data-testid*="scroll-bottom"]'
      ) || (target.closest('button') && target.closest('button').querySelector('svg path[d*="M8 12"], svg path[d*="m8 12"], svg path[d*="M7 10"], svg path[d*="13 7"]'));

      if (scrollBottomBtn) {
        const vp = document.querySelector('[data-testid="autoscroll-viewport"]');
        if (vp) {
          setTimeout(() => {
            try { vp.scrollTop = vp.scrollHeight; } catch (err) {}
          }, 0);
          setTimeout(() => {
            try { vp.scrollTop = vp.scrollHeight; } catch (err) {}
          }, 50);
        }
        return;
      }

      // 3. User toggle handling
      const trigger = target.closest(
        '[data-testid="tool-group-collapsible"], [data-testid="worked-for-collapsible"], [data-testid="thinking-collapsible-trigger"], [data-testid="run-command-step"], [data-testid="terminal-run-step"], [data-testid*="terminal"], [data-testid*="command"]'
      );
      if (trigger) {
        trigger.setAttribute('data-agy-user-toggled', 'true');
        const parentStep = trigger.closest('[data-testid="run-command-step"], [data-testid="terminal-run-step"], [data-testid*="terminal"], [data-testid*="command"]');
        if (parentStep) {
          parentStep.setAttribute('data-agy-user-toggled', 'true');
        }
      }
    }, true);
  }

  function isGeminiModelActive() {
    // Check model selector text or aria-label in composer
    const modelBtn = document.querySelector('[data-testid="model-selector-trigger"]') ||
                     document.querySelector('button[aria-haspopup="menu"]:has(svg)');
    const text = (modelBtn ? (modelBtn.innerText || modelBtn.getAttribute('aria-label') || '') : '').toLowerCase();
    if (text) {
      return text.includes('gemini');
    }
    // If no model button detected yet, default to false (do not collapse non-Gemini)
    return false;
  }

  function collapseTrigger(el) {
    if (!el || el.getAttribute('data-agy-user-toggled') === 'true') {
      return;
    }

    // Only collapse if the current active agent model is Gemini
    if (!isGeminiModelActive()) {
      return;
    }

    // Never collapse user message steps
    const testId = el.getAttribute('data-testid') || '';
    if (testId.includes('user')) {
      return;
    }

    // 1. Collapsible with aria-expanded="true" (e.g. tool-group-collapsible, thinking-collapsible-trigger)
    if (el.getAttribute('aria-expanded') === 'true') {
      const propsKey = Object.keys(el).find(k => k.startsWith('__reactProps$'));
      if (propsKey && el[propsKey] && typeof el[propsKey].onClick === 'function') {
        try {
          el[propsKey].onClick({ preventDefault: () => {}, stopPropagation: () => {} });
        } catch (err) {
          el.click();
        }
      } else {
        el.click();
      }
      return;
    }

    // 2. Step container with expanded supplementary/terminal view (e.g. run-command-step, terminal-run-step)
    if (testId === 'run-command-step' || testId === 'terminal-run-step' || testId.includes('command') || testId.includes('terminal')) {
      if (el.children.length > 1) {
        const btn = el.querySelector('[role="button"]') || el.firstElementChild;
        if (btn && btn.getAttribute('data-agy-user-toggled') !== 'true') {
          const propsKey = Object.keys(btn).find(k => k.startsWith('__reactProps$'));
          if (propsKey && btn[propsKey] && typeof btn[propsKey].onClick === 'function') {
            try {
              btn[propsKey].onClick({ preventDefault: () => {}, stopPropagation: () => {} });
            } catch (err) {
              btn.click();
            }
          } else {
            btn.click();
          }
        }
      }
    }
  }

  function formatMmSs(sec) {
    const s = Math.max(0, Math.floor(sec));
    const mm = String(Math.floor(s / 60)).padStart(2, '0');
    const ss = String(s % 60).padStart(2, '0');
    return `${mm}:${ss}`;
  }

  function parseToSeconds(str) {
    if (!str) return 0;
    if (/^\d+:\d+$/.test(str.trim())) {
      const parts = str.trim().split(':');
      return Number(parts[0]) * 60 + Number(parts[1]);
    }
    let sec = 0;
    const mMatch = str.match(/(\d+)\s*m(?:in)?/i);
    if (mMatch) sec += Number(mMatch[1]) * 60;
    const sMatch = str.match(/(\d+)\s*s(?:ec)?/i);
    if (sMatch) sec += Number(sMatch[1]);
    if (!mMatch && !sMatch) {
      const num = parseInt(str, 10);
      if (!isNaN(num)) sec = num;
    }
    return sec;
  }

  function formatCollapsibleHeader(btn) {
    if (!btn) return;
    const span = btn.querySelector('.text-secondary-foreground');
    if (!span) return;

    // Read ground-truth isRunning, action count, and timestamps from React Fiber
    let actions = 0;
    let isRunning = false;
    let startSec = 0;
    let endSec = 0;

    try {
      const fiberKey = Object.keys(btn).find(k => k.startsWith('__reactFiber$'));
      let f = fiberKey ? btn[fiberKey] : null;
      while (f) {
        if (f.memoizedProps) {
          if (typeof f.memoizedProps.isRunning === 'boolean') {
            isRunning = f.memoizedProps.isRunning;
          }
          if (f.memoizedProps.segment && Array.isArray(f.memoizedProps.segment.steps)) {
            const steps = f.memoizedProps.segment.steps;
            for (const s of steps) {
              if (s.step && s.step.case === 'generic') actions++;
            }
            if (steps.length > 0 && steps[0].metadata && steps[0].metadata.createdAt) {
              startSec = Number(steps[0].metadata.createdAt.seconds || 0);
            }
            if (steps.length > 0) {
              const lastMeta = steps[steps.length - 1].metadata;
              if (lastMeta) {
                const finishMeta = lastMeta.completedAt || lastMeta.createdAt;
                if (finishMeta && finishMeta.seconds) {
                  endSec = Number(finishMeta.seconds);
                }
              }
            }
          }
        }
        f = f.return;
      }
    } catch (e) {}

    // Only rely on React Fiber's native isRunning status
    // (no DOM heuristic fallbacks which cause false positives when sessions stop)

    const current = span.textContent || '';
    let elapsedSec = 0;

    if (isRunning) {
      if (startSec > 0) {
        elapsedSec = Math.max(0, Math.floor(Date.now() / 1000 - startSec));
      } else {
        if (!btn.__agyStartTime) {
          const rawMatch = current.match(/(?:Worked|Working)\s+for\s+(.+?)(?:,|$)/i);
          const parsed = parseToSeconds(rawMatch ? rawMatch[1] : '');
          btn.__agyStartTime = (Date.now() / 1000) - parsed;
        }
        elapsedSec = Math.max(0, Math.floor(Date.now() / 1000 - btn.__agyStartTime));
      }
      btn.__agyLastElapsedSec = elapsedSec;
    } else {
      if (endSec > 0 && startSec > 0 && endSec >= startSec) {
        elapsedSec = endSec - startSec;
      } else if (btn.__agyLastElapsedSec) {
        elapsedSec = btn.__agyLastElapsedSec;
      } else {
        const rawMatch = current.match(/(?:Worked|Working)\s+for\s+(.+?)(?:,|$)/i);
        elapsedSec = parseToSeconds(rawMatch ? rawMatch[1] : '');
      }
      delete btn.__agyStartTime;
    }

    const timePart = formatMmSs(elapsedSec);
    const prefix = isRunning ? 'Working for' : 'Worked for';
    const actionText = actions === 1 ? '1 action performed' : `${actions} actions performed`;

    let targetText = '';
    if (actions > 0) {
      targetText = `${prefix} ${timePart}, ${actionText}`;
    } else {
      targetText = `${prefix} ${timePart}`;
    }

    if (span.textContent !== targetText) {
      // Sentinel: mark span so our MutationObserver ignores the characterData
      // mutation that span.textContent = … is about to fire, preventing an
      // infinite re-entry loop.
      span.setAttribute('data-agy-writing', '1');
      span.textContent = targetText;
      // Remove asynchronously so the sentinel survives the synchronous
      // MutationObserver microtask flush triggered by the write above.
      Promise.resolve().then(() => span.removeAttribute('data-agy-writing'));
    }
    // Enforce LTR bidi isolation on the span so surrounding RTL context
    // (e.g. dir="rtl" on an ancestor set by rtl-payload) cannot flip
    // brackets or reorder characters.
    if (span.getAttribute('dir') !== 'ltr') {
      span.setAttribute('dir', 'ltr');
      span.style.direction = 'ltr';
      span.style.textAlign = 'left';
      span.style.unicodeBidi = 'isolate';
    }
  }

  function isResponseGenerating() {
    return Boolean(
      document.querySelector('button[aria-label*="Stop" i]') ||
      document.querySelector('button[aria-label*="Cancel" i]') ||
      document.querySelector('[data-testid="stop-button"]') ||
      document.querySelector('button[aria-label="Stop generating"]')
    );
  }

  function disableAutoScrollInViewports(root = document) {
    // Only suppress auto-scrolling when the assistant is actively generating a response
    if (!isResponseGenerating()) {
      return;
    }
    const viewports = root.querySelectorAll ? root.querySelectorAll('[data-testid="autoscroll-viewport"]') : [];
    viewports.forEach(vp => {
      // Find the latest user input step in this viewport
      const userSteps = vp.querySelectorAll('[data-testid="user-input-step"]');
      const latestUserStep = userSteps.length > 0 ? userSteps[userSteps.length - 1] : null;

      if (latestUserStep && window.__ANTIGRAVITY_PLUS_LAST_ALIGNED_USER_STEP !== latestUserStep) {
        window.__ANTIGRAVITY_PLUS_LAST_ALIGNED_USER_STEP = latestUserStep;
        // Find turn container or sticky header
        const turnContainer = latestUserStep.closest('.scroll-mt-4') || latestUserStep;
        let offset = 0;
        let curr = turnContainer;
        while (curr && curr !== vp) {
          offset += curr.offsetTop;
          curr = curr.offsetParent;
        }
        // Smoothly or immediately align the user prompt near the top of the viewport
        try {
          vp.scrollTop = Math.max(0, offset - 10);
        } catch (e) {}
      }

      // Ensure shouldAutoScroll ref is set to false so subsequent streaming tokens don't drag the view down
      const fiberKey = Object.keys(vp).find(k => k.startsWith('__reactFiber$'));
      let fiber = fiberKey ? vp[fiberKey] : null;
      while (fiber) {
        if (fiber.memoizedProps && fiber.memoizedProps.showScrollToBottomButton !== undefined) break;
        fiber = fiber.return;
      }
      if (!fiber) return;
      let s = fiber.memoizedState;
      let idx = 0;
      while (s) {
        // hook idx 2 in WL is shouldAutoScroll ref
        if (idx === 2 && s.memoizedState && typeof s.memoizedState === 'object' && 'current' in s.memoizedState) {
          if (s.memoizedState.current !== false) {
            s.memoizedState.current = false;
          }
          break;
        }
        idx++;
        s = s.next;
      }
    });
  }

  function checkAndCollapse(root = document) {
    // 1. Format all worked-for headers
    const allWorkedFor = root.querySelectorAll('[data-testid="worked-for-collapsible"]');
    allWorkedFor.forEach(formatCollapsibleHeader);

    // 2. Prevent auto-scrolling down in conversation viewports
    disableAutoScrollInViewports(root);

    // 3. Check aria-expanded collapsibles (worked-for accordion, tool groups, thinking)
    const collapsibles = root.querySelectorAll(
      '[data-testid="worked-for-collapsible"][aria-expanded="true"], [data-testid="tool-group-collapsible"][aria-expanded="true"], [data-testid="thinking-collapsible-trigger"][aria-expanded="true"]'
    );
    collapsibles.forEach(el => {
      if (el.getAttribute('data-agy-user-toggled') !== 'true') {
        collapseTrigger(el);
      }
    });

    // 4. Check command / step elements with expanded output (exclude user-input-step)
    const stepElements = root.querySelectorAll(
      '[data-testid="run-command-step"], [data-testid="terminal-run-step"]'
    );
    stepElements.forEach(el => {
      if (el.getAttribute('data-agy-user-toggled') !== 'true' && el.children.length > 1) {
        collapseTrigger(el);
      }
    });
  }

  // MutationObserver to auto-collapse newly created or updated running tool groups and commands
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      const target = m.target;

      // ── Guard: skip mutations we fired ourselves via span.textContent ──
      // formatCollapsibleHeader sets data-agy-writing before writing textContent.
      // MutationObserver callbacks are synchronous, so the sentinel is still
      // present when this callback runs for characterData mutations.
      if (m.type === 'characterData') {
        const ownerEl = target.parentElement;
        if (ownerEl && ownerEl.getAttribute('data-agy-writing') === '1') {
          continue; // our own write — skip to avoid infinite loop
        }
      }

      const el = target.nodeType === Node.ELEMENT_NODE ? target : target.parentElement;
      const workedForBtn = el ? el.closest('[data-testid="worked-for-collapsible"]') : null;
      if (workedForBtn) {
        formatCollapsibleHeader(workedForBtn);
      }

      if (m.type === 'attributes') {
        if (!target || target.getAttribute('data-agy-user-toggled') === 'true') {
          continue;
        }
        const testId = target && target.getAttribute ? (target.getAttribute('data-testid') || '') : '';
        const isUserStep = testId.includes('user');
        if (isUserStep) {
          continue;
        }
        if (m.attributeName === 'aria-expanded' && target.getAttribute('aria-expanded') === 'true') {
          if (testId === 'worked-for-collapsible' || testId === 'tool-group-collapsible' || testId === 'thinking-collapsible-trigger' || testId === 'run-command-step' || testId === 'terminal-run-step' || testId.includes('command') || testId.includes('terminal')) {
            collapseTrigger(target);
          }
        } else if (m.attributeName === 'class' && testId === 'worked-for-collapsible') {
          if (target.getAttribute('aria-expanded') === 'true') {
            collapseTrigger(target);
          }
        }
      } else if (m.addedNodes.length > 0) {
        m.addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            const testId = node.getAttribute ? (node.getAttribute('data-testid') || '') : '';
            if (testId.includes('user')) {
              return;
            }
            if (testId === 'worked-for-collapsible') {
              formatCollapsibleHeader(node);
            }
            if ((testId === 'worked-for-collapsible' || testId === 'tool-group-collapsible') && node.getAttribute('aria-expanded') === 'true') {
              collapseTrigger(node);
            } else if (testId === 'run-command-step' || testId === 'terminal-run-step' || testId.includes('command') || testId.includes('terminal')) {
              collapseTrigger(node);
            } else if (node.querySelectorAll) {
              checkAndCollapse(node);
            }
          }
        });
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    characterData: true,
    attributeFilter: ['aria-expanded', 'data-testid', 'class']
  });

  // Background ticker to keep headers fresh and auto-scrolling suppressed
  window.__ANTIGRAVITY_PLUS_HEADER_INTERVAL = setInterval(() => {
    const btns = document.querySelectorAll('[data-testid="worked-for-collapsible"]');
    btns.forEach(formatCollapsibleHeader);
    disableAutoScrollInViewports(document);
  }, 300);

  window.__ANTIGRAVITY_PLUS_UI_OBSERVER = observer;
  window.__ANTIGRAVITY_PLUS_UI_INSTALLED = true;

  // Initial pass to collapse any currently open running tool groups and command outputs
  checkAndCollapse(document);

  console.log('[Antigravity Plus] UI Enhancements installed (Auto-collapse agent messages & commands, auto-scroll prevention, hidden Working message, hidden notification toast).');
})();
'@
}

