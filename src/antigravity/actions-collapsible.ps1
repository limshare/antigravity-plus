function Get-AntigravityActionsCollapsiblePayload {
    @'
(function () {
  if (window.__ANTIGRAVITY_PLUS_ACTIONS_COLLAPSIBLE) {
    try { window.__ANTIGRAVITY_PLUS_ACTIONS_COLLAPSIBLE.cleanup(); } catch (e) {}
  }

  const STYLE_ID = 'antigravity-plus-actions-collapsible-style';
  let styleEl = document.getElementById(STYLE_ID);
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = STYLE_ID;
    (document.head || document.documentElement).appendChild(styleEl);
  }
  styleEl.textContent = `
    .agy-actions-group-wrapper {
      margin: 4px 0 6px 0 !important;
      border-radius: 6px !important;
      overflow: hidden !important;
      direction: ltr !important;
      unicode-bidi: isolate !important;
      text-align: left !important;
    }
    .agy-actions-group-header {
      display: flex !important;
      align-items: center !important;
      gap: 6px !important;
      width: 100% !important;
      text-align: left !important;
      font-size: 12px !important;
      padding: 3px 8px !important;
      min-height: 28px !important;
      border-radius: 6px !important;
      background: rgba(128, 128, 128, 0.08) !important;
      color: inherit !important;
      opacity: 0.85 !important;
      border: 1px solid rgba(128, 128, 128, 0.16) !important;
      cursor: pointer !important;
      user-select: none !important;
      transition: background 0.15s ease, opacity 0.15s ease !important;
      font-family: inherit !important;
      line-height: 1.4 !important;
    }
    .agy-actions-group-header:hover {
      background: rgba(128, 128, 128, 0.16) !important;
      opacity: 1 !important;
    }
    .agy-actions-group-chevron {
      width: 12px !important;
      height: 12px !important;
      flex-shrink: 0 !important;
      transition: transform 0.2s ease !important;
      opacity: 0.7 !important;
    }
    .agy-actions-group-header[aria-expanded="true"] .agy-actions-group-chevron {
      transform: rotate(90deg) !important;
    }
    .agy-actions-group-title {
      font-size: 12px !important;
      font-weight: 500 !important;
      color: inherit !important;
      white-space: nowrap !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
    }
    .agy-actions-group-body {
      padding: 2px 0 2px 8px !important;
      border-left: 2px solid rgba(128, 128, 128, 0.2) !important;
      margin-left: 6px !important;
      margin-top: 3px !important;
    }
  `;

  function isActionStepNode(node) {
    if (!node || node.nodeType !== Node.ELEMENT_NODE) return false;
    if (node.hasAttribute('data-agy-actions-group') || node.classList.contains('agy-actions-group-wrapper')) return false;
    if (node.classList.contains('agy-thinking-translated')) return false;

    // Explicitly exclude main worked-for accordion button and its parent wrapper
    const testId = node.getAttribute('data-testid') || '';
    if (testId === 'worked-for-collapsible' || node.querySelector('[data-testid="worked-for-collapsible"]')) {
      return false;
    }

    // Do not group user steps, system toolbars, feedback or prompt boxes
    if (
      testId.includes('user') ||
      testId.includes('toolbar') ||
      testId.includes('revert') ||
      testId.includes('input') ||
      testId.includes('turn-cards') ||
      testId.includes('composer')
    ) {
      return false;
    }

    // Do not group thinking blocks
    if (testId === 'thinking-collapsible-trigger' || node.querySelector('[data-testid="thinking-collapsible-trigger"]')) {
      return false;
    }
    const text = (node.innerText || node.textContent || '').trim();
    if (text.startsWith('Thought for ') || text.startsWith('Thinking')) {
      return false;
    }

    // Identify action/step elements (Analyzed, Edited, Ran, Explored, diffs, tool executions)
    if (
      testId.includes('view-file') ||
      testId.includes('run-command') ||
      testId.includes('terminal') ||
      testId.includes('write-file') ||
      testId.includes('edit-file') ||
      testId.includes('tool-group') ||
      testId.includes('diff-line') ||
      text.includes('Analyzed') ||
      text.includes('Edited') ||
      text.includes('Explored') ||
      text.includes('Ran ') ||
      text.includes('actions performed') ||
      (testId.includes('step') && !testId.includes('user') && !testId.includes('thinking'))
    ) {
      return true;
    }

    return false;
  }

  function summarizeActionItems(elements) {
    let analyzedCount = 0;
    let editedCount = 0;
    let ranCount = 0;
    let exploredCount = 0;
    let otherCount = 0;

    for (const el of elements) {
      const txt = (el.innerText || el.textContent || '').trim();
      if (txt.includes('Analyzed')) {
        analyzedCount++;
      } else if (txt.includes('Edited')) {
        editedCount++;
      } else if (txt.includes('Ran')) {
        ranCount++;
      } else if (txt.includes('Explored')) {
        exploredCount++;
      } else {
        otherCount++;
      }
    }

    const parts = [];
    if (analyzedCount > 0) parts.push(`Analyzed ${analyzedCount} file${analyzedCount > 1 ? 's' : ''}`);
    if (editedCount > 0) parts.push(`Edited ${editedCount} file${editedCount > 1 ? 's' : ''}`);
    if (ranCount > 0) parts.push(`Ran commands`);
    if (exploredCount > 0) parts.push(`Explored files`);
    if (parts.length === 0 && otherCount > 0) parts.push(`${otherCount} action${otherCount > 1 ? 's' : ''}`);

    return parts.join(', ') || `${elements.length} actions`;
  }

  function groupActionsInContainer(container) {
    if (!container || !container.children) return;

    const children = Array.from(container.children);
    let currentGroup = [];

    function flushGroup() {
      if (currentGroup.length === 0) return;
      const groupElements = currentGroup;
      currentGroup = [];

      const firstEl = groupElements[0];
      const wrapper = document.createElement('div');
      wrapper.className = 'agy-actions-group-wrapper';
      wrapper.setAttribute('data-agy-actions-group', 'true');

      const count = groupElements.length;
      const summary = summarizeActionItems(groupElements);
      const titleLabel = `${count} ${count === 1 ? 'action' : 'actions'} (${summary})`;

      const header = document.createElement('button');
      header.type = 'button';
      header.className = 'agy-actions-group-header';
      header.setAttribute('aria-expanded', 'false');
      header.innerHTML = `
        <svg class="agy-actions-group-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="9 18 15 12 9 6"></polyline>
        </svg>
        <span class="agy-actions-group-title">${titleLabel}</span>
      `;

      const body = document.createElement('div');
      body.className = 'agy-actions-group-body';
      body.style.display = 'none';

      header.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        const expanded = header.getAttribute('aria-expanded') === 'true';
        if (expanded) {
          header.setAttribute('aria-expanded', 'false');
          body.style.display = 'none';
        } else {
          header.setAttribute('aria-expanded', 'true');
          body.style.display = 'block';
        }
      });

      container.insertBefore(wrapper, firstEl);
      wrapper.appendChild(header);
      wrapper.appendChild(body);

      for (const item of groupElements) {
        body.appendChild(item);
      }
    }

    for (const child of children) {
      if (isActionStepNode(child)) {
        currentGroup.push(child);
      } else {
        flushGroup();
      }
    }
    flushGroup();
  }

  function processAllTurnContainers(root = document) {
    // 1. Locate containers around thinking triggers
    const thinkingTriggers = root.querySelectorAll('[data-testid="thinking-collapsible-trigger"]');
    const processedContainers = new Set();

    for (const trigger of thinkingTriggers) {
      let container = trigger.parentElement;
      while (container && container.children.length <= 2 && container.parentElement && container.parentElement !== document.body) {
        container = container.parentElement;
      }
      if (container && !processedContainers.has(container)) {
        processedContainers.add(container);
        groupActionsInContainer(container);
      }
    }

    // 2. Also search for any general step lists containing Analyzed or Edited items
    const actionSampleNodes = Array.from(root.querySelectorAll('*')).filter(el => {
      const t = el.innerText || '';
      return (t.includes('Analyzed ') || t.includes('Edited ')) && el.children.length <= 2;
    });

    for (const sample of actionSampleNodes) {
      let container = sample.parentElement;
      while (container && container.children.length <= 2 && container.parentElement && container.parentElement !== document.body) {
        container = container.parentElement;
      }
      if (container && !processedContainers.has(container) && !container.classList.contains('agy-actions-group-body')) {
        processedContainers.add(container);
        groupActionsInContainer(container);
      }
    }
  }

  // Initial pass
  processAllTurnContainers();

  const intervalId = setInterval(() => {
    processAllTurnContainers();
  }, 800);

  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.addedNodes.length > 0) {
        for (const node of m.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            if (isActionStepNode(node)) {
              if (node.parentElement && !node.parentElement.classList.contains('agy-actions-group-body')) {
                groupActionsInContainer(node.parentElement);
              }
            } else if (node.querySelectorAll) {
              const innerActions = node.querySelectorAll('[data-testid*="step"], [data-testid*="tool"]');
              if (innerActions.length > 0) {
                processAllTurnContainers(node);
              }
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

  window.__ANTIGRAVITY_PLUS_ACTIONS_COLLAPSIBLE = {
    cleanup: function () {
      clearInterval(intervalId);
      observer.disconnect();
    },
    processAllTurnContainers,
    groupActionsInContainer,
    isActionStepNode,
    summarizeActionItems
  };
})();
'@
}
