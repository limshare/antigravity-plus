function Get-AntigravityUiEnhancementsPayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_UI_OBSERVER) {
    try { window.__ANTIGRAVITY_PLUS_UI_OBSERVER.disconnect(); } catch (e) {}
  }

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
  `;

  // Track manual user clicks so user-expanded sections stay expanded
  if (!window.__ANTIGRAVITY_PLUS_USER_TOGGLE_LISTENER) {
    window.__ANTIGRAVITY_PLUS_USER_TOGGLE_LISTENER = true;
    document.addEventListener('click', (e) => {
      const trigger = e.target.closest && e.target.closest(
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

  function collapseTrigger(el) {
    if (!el || el.getAttribute('data-agy-user-toggled') === 'true') {
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

  function checkAndCollapse(root = document) {
    // 1. Check aria-expanded collapsibles (tool groups, thinking)
    const collapsibles = root.querySelectorAll(
      '[data-testid="tool-group-collapsible"][aria-expanded="true"], [data-testid="thinking-collapsible-trigger"][aria-expanded="true"]'
    );
    collapsibles.forEach(el => {
      if (el.getAttribute('data-agy-user-toggled') !== 'true') {
        collapseTrigger(el);
      }
    });

    // 2. Check command / step elements with expanded output (exclude user-input-step)
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
      if (m.type === 'attributes' && m.attributeName === 'aria-expanded') {
        const target = m.target;
        if (target && target.getAttribute('aria-expanded') === 'true' && target.getAttribute('data-agy-user-toggled') !== 'true') {
          const testId = target.getAttribute('data-testid') || '';
          if (testId.includes('user')) {
            continue;
          }
          if (testId === 'tool-group-collapsible' || testId === 'thinking-collapsible-trigger' || testId === 'run-command-step' || testId === 'terminal-run-step' || testId.includes('command') || testId.includes('terminal')) {
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
            if (testId === 'tool-group-collapsible' && node.getAttribute('aria-expanded') === 'true') {
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
    attributeFilter: ['aria-expanded', 'data-testid']
  });

  window.__ANTIGRAVITY_PLUS_UI_OBSERVER = observer;
  window.__ANTIGRAVITY_PLUS_UI_INSTALLED = true;

  // Initial pass to collapse any currently open running tool groups and command outputs
  checkAndCollapse(document);

  console.log('[Antigravity Plus] UI Enhancements installed (Auto-collapse agent messages & commands, hidden Working message, hidden notification toast).');
})();
'@
}

