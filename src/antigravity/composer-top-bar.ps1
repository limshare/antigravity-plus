function Get-AntigravityComposerTopBarPayload {
    @'
(function () {
  const TOP_BAR_ATTR = 'data-gemini-plus-composer-top-bar';
  const PROJECT_BTN_ATTR = 'data-gemini-plus-composer-project-btn';
  const CHEVRON_ATTR = 'data-gemini-plus-composer-project-chevron';
  const NEW_CHAT_BTN_ATTR = 'data-gemini-plus-composer-new-chat';
  const GIT_GROUP_ATTR = 'data-gemini-plus-composer-git-group';
  const COMMIT_BTN_ATTR = 'data-gemini-plus-composer-commit';
  const PUSH_BTN_ATTR = 'data-gemini-plus-composer-push';
  const BRANCH_VAL_ATTR = 'data-gemini-plus-composer-branch';
  const PROJECT_VAL_ATTR = 'data-gemini-plus-composer-project';
  const PROCESS_BADGE_ATTR = 'data-gemini-plus-composer-process';
  const PROCESS_COUNT_ATTR = 'data-gemini-plus-process-count';
  const BUILD_VERSION = '2026.09.10.1';
  const STYLE_ID = 'gemini-plus-composer-top-bar-style';

  if (window.__GEMINI_PLUS_COMPOSER_TOP_BAR && window.__GEMINI_PLUS_COMPOSER_TOP_BAR.observer) {
    try { window.__GEMINI_PLUS_COMPOSER_TOP_BAR.observer.disconnect(); } catch (e) {}
  }

  function ensureStyles() {
    let style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = `
      @keyframes gemini-plus-spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
      }

      [data-gemini-plus-composer-top-bar] {
        position: relative;
        display: flex;
        align-items: center;
        gap: 8px;
        width: 100%;
        box-sizing: border-box;
        padding: 8px 14px 4px 14px;
        border-top-left-radius: 16px !important;
        border-top-right-radius: 16px !important;
        border-bottom-left-radius: 0 !important;
        border-bottom-right-radius: 0 !important;
        margin-bottom: 0 !important;
        border: 1px solid var(--border, rgba(128, 128, 128, 0.25)) !important;
        border-bottom: 0 !important;
        background: var(--background-secondary, rgba(128, 128, 128, 0.08)) !important;
        backdrop-filter: blur(8px);
        color: var(--vscode-foreground, currentColor);
        font-size: 13px;
        font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
        line-height: 1.2;
        user-select: none;
        z-index: 10;
      }

      /* Seamless connection: no border, no padding-top, no top radius on the composer card directly below */
      [data-gemini-plus-composer-top-bar] + * {
        border-top-left-radius: 0 !important;
        border-top-right-radius: 0 !important;
        border-top: 0 !important;
        padding-top: 0 !important;
        margin-top: 0 !important;
      }

      [data-gemini-plus-composer-top-bar] + * > .bg-card {
        border-top-left-radius: 0 !important;
        border-top-right-radius: 0 !important;
        border-top: 0 !important;
      }

      [data-gemini-plus-composer-process] {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        padding: 2px 7px;
        border-radius: 12px;
        background: rgba(59, 130, 246, 0.15);
        color: #3b82f6;
        font-size: 12px;
        font-weight: 600;
        line-height: 1;
        cursor: default;
        transition: all 0.2s ease;
      }

      [data-gemini-plus-composer-process] svg {
        animation: gemini-plus-spin 3s linear infinite;
      }

      /* Hide bulky background process widget above composer when composer top bar is active */
      [data-gemini-plus-hide-bulky-process="true"] {
        display: none !important;
      }

      /* Hide redundant native empty-state project selector above composer */
      .no-focus-agent-input:has([data-testid="project-selector-trigger"]),
      .no-focus-agent-input:has(button[aria-label*="Select project" i]) {
        position: absolute !important;
        opacity: 0 !important;
        pointer-events: none !important;
        height: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        overflow: hidden !important;
      }

      [data-gemini-plus-composer-commit]:disabled,
      [data-gemini-plus-composer-push]:disabled {
        opacity: 0.45 !important;
        cursor: not-allowed !important;
        pointer-events: auto !important;
      }
    `;
  }

  ensureStyles();

  function normalizeText(text) {
    return String(text || '').replace(/\s+/g, ' ').trim();
  }

  function currentProjectName() {
    // 0. Resolve from live project selector trigger if present (in new chat / empty state)
    const nativeTrigger = document.querySelector('[data-testid="project-selector-trigger"], button[aria-label*="Select project" i]');
    if (nativeTrigger) {
      const span = nativeTrigger.querySelector('span');
      const val = normalizeText(span ? span.textContent : nativeTrigger.textContent);
      if (val) {
        try { sessionStorage.setItem('antigravity_plus_last_project', val); } catch (e) {}
        return val;
      }
    }

    const breadcrumb = document.querySelector('[data-testid="breadcrumb-segment"]');
    if (breadcrumb) {
      const val = normalizeText(breadcrumb.textContent);
      if (val && !val.toLowerCase().includes('chat') && !val.toLowerCase().includes('task')) {
        try { sessionStorage.setItem('antigravity_plus_last_project', val); } catch (e) {}
        return val;
      }
    }

    // 1. Resolve from sidebar React Fiber items
    const sidebar = document.querySelector('[data-testid="conversation-list-sidebar"]');
    if (sidebar) {
      const fiberKey = Object.keys(sidebar).find((k) => k.startsWith('__reactFiber$'));
      if (fiberKey) {
        let fiber = sidebar[fiberKey];
        let items = null;
        while (fiber) {
          if (fiber.memoizedProps && fiber.memoizedProps.items) {
            items = fiber.memoizedProps.items;
            break;
          }
          fiber = fiber.return;
        }

        if (items && Array.isArray(items)) {
          const projectMap = {};
          items.forEach((i) => {
            if ((i.type === 'header' || i.type === 'project') && i.id && (i.label || i.name)) {
              const label = normalizeText(i.label || i.name);
              projectMap[i.id] = label;
              projectMap[i.id.replace(/^header-/, '')] = label;
            }
          });

          const urlParams = new URLSearchParams(location.search);
          const sectionId = urlParams.get('section');
          if (sectionId && projectMap[sectionId]) {
            try { sessionStorage.setItem('antigravity_plus_last_project', projectMap[sectionId]); } catch (e) {}
            return projectMap[sectionId];
          }

          const threadMatch = location.pathname.match(/\/c\/([a-zA-Z0-9_-]+)/);
          const currentThreadId = threadMatch ? threadMatch[1] : null;
          if (currentThreadId) {
            const currentItem = items.find((i) => i.cascadeId === currentThreadId);
            if (currentItem) {
              const projId = currentItem.groupId || currentItem.summary?.trajectoryMetadata?.projectId;
              if (projId && projectMap[projId]) {
                try { sessionStorage.setItem('antigravity_plus_last_project', projectMap[projId]); } catch (e) {}
                return projectMap[projId];
              }
            }
          }
        }
      }
    }

    try {
      const cachedMap = JSON.parse(localStorage.getItem('antigravity_plus_project_names') || '{}');
      const threadMatch = location.pathname.match(/\/c\/([a-zA-Z0-9_-]+)/);
      if (threadMatch && cachedMap[threadMatch[1]]) {
        return cachedMap[threadMatch[1]];
      }
    } catch (e) {}

    try {
      const sessionProj = sessionStorage.getItem('antigravity_plus_last_project');
      if (sessionProj) return sessionProj;
    } catch (e) {}

    return localStorage.getItem('antigravity_plus_last_project') || 'Workspace';
  }

  function isNewChat() {
    if (document.querySelector('[data-testid="project-selector-trigger"], button[aria-label*="Select project" i]')) {
      return true;
    }
    const path = location.pathname;
    if (path === '/' || path === '' || path === '/task/new' || path === '/c/new') {
      return true;
    }
    return false;
  }

  function currentBranchName() {
    const cached = localStorage.getItem('antigravity_plus_branch');
    if (cached) return cached;

    const branchEl = document.querySelector('[data-git-branch], [aria-label*="branch" i], .git-branch-label');
    if (branchEl) {
      const val = normalizeText(branchEl.textContent);
      if (val) return val;
    }

    return 'main';
  }

  function getRunningProcessCount() {
    if (typeof window.__ANTIGRAVITY_PLUS_RUNNING_PROCESSES_COUNT === 'number') {
      return Math.max(0, window.__ANTIGRAVITY_PLUS_RUNNING_PROCESSES_COUNT);
    }

    const anchor = findComposerAnchor();
    if (!anchor || !anchor.container) return 0;

    // Must be scoped strictly to the current session's composer area (directly above the composer)
    const topBar = anchor.container.querySelector('[' + TOP_BAR_ATTR + ']');
    const aboveComposer = topBar ? topBar.previousElementSibling : (anchor.insertBefore ? anchor.insertBefore.previousElementSibling : null);

    if (!aboveComposer) return 0;

    // Find any background process / task / running command items specifically inside the active session's above-composer container
    const processItems = Array.from(aboveComposer.children).filter((child) => {
      if (child.hasAttribute(TOP_BAR_ATTR)) return false;
      const text = (child.textContent || '').trim().toLowerCase();
      const testId = (child.getAttribute('data-testid') || '').toLowerCase();
      const cls = (child.className || '').toString().toLowerCase();

      const isProcess = testId.includes('process') || testId.includes('task') ||
                        cls.includes('process') || cls.includes('task') ||
                        cls.includes('banner') ||
                        text.includes('background') || text.includes('running') ||
                        child.querySelector('.animate-spin, button[aria-label*="Stop" i], button[aria-label*="Cancel" i]') !== null;

      return isProcess || (text.length > 0 && child.offsetParent !== null);
    });

    return processItems.length;
  }

  function createProjectFolderIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('viewBox', '0 0 20 20');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<path d="M2.5 5.5A1.5 1.5 0 0 1 4 4h3.379a1.5 1.5 0 0 1 1.06.44l1.122 1.12a1.5 1.5 0 0 0 1.06.44H16A1.5 1.5 0 0 1 17.5 7.5v7A1.5 1.5 0 0 1 16 16H4a1.5 1.5 0 0 1-1.5-1.5v-9Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/>';
    return svg;
  }

  function createChevronDownIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '12');
    svg.setAttribute('height', '12');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.style.opacity = '0.75';
    svg.innerHTML = '<path d="M4 6l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
    return svg;
  }

  function createLocationIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('viewBox', '0 0 20 20');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<rect x="2.5" y="4.5" width="15" height="10.5" rx="1.5" stroke="currentColor" stroke-width="1.4"/><path d="M6 17h8" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>';
    return svg;
  }

  function createBranchIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('viewBox', '0 0 20 20');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<circle cx="6" cy="5" r="1.7" stroke="currentColor" stroke-width="1.4"/><circle cx="14" cy="15" r="1.7" stroke="currentColor" stroke-width="1.4"/><path d="M6 6.7v4.1c0 1.4 1.1 2.5 2.5 2.5H12M6 6.7v1.1c0 1.4 1.1 2.5 2.5 2.5H12V13.3" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>';
    return svg;
  }

  function createProcessIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<circle cx="8" cy="8" r="2.5" stroke="currentColor" stroke-width="1.3"/><path d="M8 1.5v1.8M8 12.7v1.8M1.5 8h1.8M12.7 8h1.8M3.4 3.4l1.3 1.3M11.3 11.3l1.3 1.3M3.4 12.6l1.3-1.3M11.3 4.7l1.3-1.3" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>';
    return svg;
  }

  function createNewChatIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<path d="M8 3v10M3 8h10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>';
    return svg;
  }

  function createCommitIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<circle cx="8" cy="8" r="3" stroke="currentColor" stroke-width="1.4"/><path d="M8 1.5v3.5M8 11v3.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>';
    return svg;
  }

  function createPushIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.flexShrink = '0';
    svg.innerHTML = '<path d="M8 11.5V3.5M4.5 7 8 3.5 11.5 7M3 13.5h10" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>';
    return svg;
  }

  function getGitActionStates() {
    let vcsBtn = Array.from(document.querySelectorAll('button')).find((b) => {
      if (b.closest('[' + TOP_BAR_ATTR + ']')) return false;
      if (b.closest('[role="dialog"], [role="menu"], [data-radix-popper-content-wrapper]')) return false;
      const text = (b.innerText || '').trim().toLowerCase();
      const aria = (b.getAttribute('aria-label') || '').trim().toLowerCase();
      return text === 'push' || text === 'commit' || aria === 'push' || aria === 'commit';
    });

    if (!vcsBtn) {
      return {
        available: false,
        commit: { available: false, label: 'Commit', disabled: true, run: null },
        push: { available: false, label: 'Push', disabled: true, run: null }
      };
    }

    let mtFiber = null;
    const k = Object.keys(vcsBtn).find((k) => k.startsWith('__reactFiber$'));
    if (k) {
      let f = vcsBtn[k];
      while (f) {
        if (f.memoizedProps && (f.memoizedProps.actions || f.memoizedProps.onMainClick)) {
          mtFiber = f;
          break;
        }
        f = f.return;
      }
    }

    if (mtFiber && mtFiber.memoizedProps) {
      const props = mtFiber.memoizedProps;
      const mainLabel = (vcsBtn ? vcsBtn.innerText : '').trim() || 'Push';
      const mainDisabled = Boolean(props.disabled);
      const mainHandler = typeof props.onMainClick === 'function' ? props.onMainClick : null;

      const actions = Array.isArray(props.actions) ? props.actions : [];
      const other = actions[0];
      const otherDisabled = other ? Boolean(other.disabled || props.disabled) : true;
      const otherHandler = other && typeof other.onSelect === 'function' ? other.onSelect : null;

      const isCommitMain = mainLabel.toLowerCase().includes('commit');
      const isPushMain = mainLabel.toLowerCase().includes('push');
      const hasOther = Boolean(other);

      const runCommit = () => {
        if (isCommitMain) {
          if (vcsBtn && typeof vcsBtn.click === 'function') {
            try { vcsBtn.click(); } catch (e) {}
          }
          if (typeof mainHandler === 'function') {
            try { mainHandler(); } catch (e) {}
          }
        } else if (other && typeof other.onSelect === 'function') {
          other.onSelect();
        } else if (typeof otherHandler === 'function') {
          otherHandler();
        } else if (vcsBtn) {
          vcsBtn.click();
        }
      };

      const runPush = () => {
        if (isPushMain) {
          if (vcsBtn && typeof vcsBtn.click === 'function') {
            try { vcsBtn.click(); } catch (e) {}
          }
          if (typeof mainHandler === 'function') {
            try { mainHandler(); } catch (e) {}
          }
        } else if (other && typeof other.onSelect === 'function') {
          other.onSelect();
        } else if (typeof otherHandler === 'function') {
          otherHandler();
        } else if (vcsBtn) {
          vcsBtn.click();
        }
      };

      return {
        available: true,
        commit: {
          available: isCommitMain || (hasOther && other.label && String(other.label).toLowerCase().includes('commit')),
          label: 'Commit',
          disabled: isCommitMain ? mainDisabled : otherDisabled,
          run: runCommit
        },
        push: {
          available: isPushMain || (hasOther && other.label && String(other.label).toLowerCase().includes('push')),
          label: 'Push',
          disabled: isPushMain ? mainDisabled : otherDisabled,
          run: runPush
        }
      };
    }

    const rawText = (vcsBtn.innerText || '').trim().toLowerCase();
    const isCommit = rawText.includes('commit');
    const isPush = rawText.includes('push');
    return {
      available: true,
      commit: {
        available: isCommit,
        label: 'Commit',
        disabled: Boolean(vcsBtn.disabled),
        run: () => { if (isCommit && vcsBtn && !vcsBtn.disabled) vcsBtn.click(); }
      },
      push: {
        available: isPush,
        label: 'Push',
        disabled: Boolean(vcsBtn.disabled),
        run: () => { if (isPush && vcsBtn && !vcsBtn.disabled) vcsBtn.click(); }
      }
    };
  }

  function triggerProjectSelect(anchorEl) {
    if (!isNewChat()) return;
    const nativeTrigger = document.querySelector('[data-testid="project-selector-trigger"], button[aria-label*="Select project" i]');
    if (nativeTrigger) {
      if (anchorEl) {
        const rect = anchorEl.getBoundingClientRect();
        nativeTrigger.style.position = 'fixed';
        nativeTrigger.style.top = rect.top + 'px';
        nativeTrigger.style.left = rect.left + 'px';
        nativeTrigger.style.width = rect.width + 'px';
        nativeTrigger.style.height = rect.height + 'px';
        nativeTrigger.style.zIndex = '-1';
        nativeTrigger.style.opacity = '0';
        nativeTrigger.style.pointerEvents = 'none';
      }
      try {
        nativeTrigger.click();
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] Error clicking native project trigger:', e);
      }
    }
  }

  function syncProjectElement(bar) {
    if (!bar) return;
    const project = bar.querySelector('[' + PROJECT_BTN_ATTR + ']');
    const projectText = bar.querySelector('[' + PROJECT_VAL_ATTR + ']');
    const chevron = bar.querySelector('[' + CHEVRON_ATTR + ']');
    if (!project || !projectText) return;

    projectText.textContent = currentProjectName();

    const canSelect = isNewChat();
    if (chevron) {
      chevron.style.display = canSelect ? 'inline-flex' : 'none';
    }

    if (canSelect) {
      project.style.cursor = 'pointer';
      project.style.pointerEvents = 'auto';
      project.title = 'Switch workspace / project';
      project.setAttribute('aria-label', 'Select project');
      project.setAttribute('aria-disabled', 'false');
    } else {
      project.style.cursor = 'default';
      project.style.pointerEvents = 'none';
      project.style.background = 'transparent';
      project.title = 'Workspace: ' + projectText.textContent;
      project.setAttribute('aria-label', 'Project workspace');
      project.setAttribute('aria-disabled', 'true');
    }
  }

  function getRouter() {
    const root = document.getElementById('root') || document.body.firstElementChild;
    const k = root ? Object.keys(root).find((k) => k.startsWith('__reactContainer$') || k.startsWith('__reactFiber$')) : null;
    let current = root ? root[k] : null;
    let router = null;
    function traverse(fiber, depth = 0) {
      if (!fiber || depth > 35 || router) return;
      if (fiber.memoizedProps && fiber.memoizedProps.router && typeof fiber.memoizedProps.router.navigate === 'function') {
        router = fiber.memoizedProps.router;
        return;
      }
      if (fiber.child) traverse(fiber.child, depth + 1);
      if (fiber.sibling) traverse(fiber.sibling, depth);
    }
    traverse(current);
    return router;
  }

  function getActiveSectionId() {
    const urlParams = new URLSearchParams(location.search);
    const sec = urlParams.get('section');
    if (sec) return sec;

    const sidebar = document.querySelector('[data-testid="conversation-list-sidebar"]');
    if (sidebar) {
      const fiberKey = Object.keys(sidebar).find((k) => k.startsWith('__reactFiber$'));
      if (fiberKey && sidebar[fiberKey]) {
        let f = sidebar[fiberKey];
        while (f) {
          if (f.memoizedProps && f.memoizedProps.items) {
            const items = f.memoizedProps.items;
            const threadMatch = location.pathname.match(/\/c\/([a-zA-Z0-9_-]+)/);
            const currentThreadId = threadMatch ? threadMatch[1] : null;
            if (currentThreadId && Array.isArray(items)) {
              const currentItem = items.find((i) => i.cascadeId === currentThreadId);
              if (currentItem) {
                return currentItem.groupId || currentItem.summary?.trajectoryMetadata?.projectId || null;
              }
            }
            break;
          }
          f = f.return;
        }
      }
    }
    return null;
  }

  function focusComposerInput() {
    setTimeout(() => {
      const input = document.querySelector('[contenteditable="true"], textarea');
      if (input) {
        try {
          input.focus();
        } catch (e) {}
      }
    }, 150);
  }

  function triggerNewChat() {
    // 1. TanStack Router direct programmatic navigation (fastest & robust)
    const router = getRouter();
    const sectionId = getActiveSectionId();
    if (router && typeof router.navigate === 'function') {
      try {
        if (sectionId) {
          router.navigate({ to: '/', search: { section: sectionId } });
        } else {
          router.navigate({ to: '/' });
        }
        focusComposerInput();
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] TanStack router navigation failed:', e);
      }
    }

    // 2. Candidate DOM elements (buttons & links)
    const candidates = [
      'button[data-testid="new-conversation-button"]',
      'a[data-testid="new-conversation-button"]',
      'button[data-testid="new-task-button"]',
      'a[data-testid="new-task-button"]',
      'button[data-testid="new-chat-button"]',
      'a[data-testid="new-chat-button"]',
      'button[aria-label*="New Chat" i]',
      'a[aria-label*="New Chat" i]',
      'button[aria-label*="New conversation" i]',
      'a[aria-label*="New conversation" i]',
      'button[aria-label*="New task" i]',
      'a[aria-label*="New task" i]',
      'a[href="/"]',
      'a[href^="/?section="]'
    ];
    for (const sel of candidates) {
      const el = document.querySelector(sel);
      if (el) {
        try {
          el.click();
          focusComposerInput();
          return;
        } catch (e) {}
      }
    }

    // 3. Fallback: window navigation
    if (sectionId) {
      window.location.href = '/?section=' + encodeURIComponent(sectionId);
    } else {
      window.location.href = '/';
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-new-chat'));
    focusComposerInput();
  }

  function triggerCommitAction() {
    const states = getGitActionStates();
    if (!states.commit || !states.commit.available || states.commit.disabled) return;
    if (typeof states.commit.run === 'function') {
      try {
        states.commit.run();
        console.log('[Antigravity Plus] Native Commit action executed');
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] Native Commit execution error:', e);
      }
    }
    const nativeCommitBtn = Array.from(document.querySelectorAll('button')).find((b) => {
      if (b.closest('[' + TOP_BAR_ATTR + ']')) return false;
      const text = (b.innerText || '').trim().toLowerCase();
      return text === 'commit';
    });
    if (nativeCommitBtn && !nativeCommitBtn.disabled) {
      try {
        nativeCommitBtn.click();
        console.log('[Antigravity Plus] Fallback native Commit button clicked');
        return;
      } catch (e) {}
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-commit'));
  }

  function triggerPushAction() {
    const states = getGitActionStates();
    if (!states.push || !states.push.available || states.push.disabled) return;
    if (typeof states.push.run === 'function') {
      try {
        states.push.run();
        console.log('[Antigravity Plus] Native Push action executed');
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] Native Push execution error:', e);
      }
    }
    const nativePushBtn = Array.from(document.querySelectorAll('button')).find((b) => {
      if (b.closest('[' + TOP_BAR_ATTR + ']')) return false;
      const text = (b.innerText || '').trim().toLowerCase();
      return text === 'push';
    });
    if (nativePushBtn && !nativePushBtn.disabled) {
      try {
        nativePushBtn.click();
        console.log('[Antigravity Plus] Fallback native Push button clicked');
        return;
      } catch (e) {}
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-push'));
  }

  function createComposerTopBar() {
    const bar = document.createElement('div');
    bar.setAttribute(TOP_BAR_ATTR, 'true');
    bar.setAttribute('data-gemini-plus-version', BUILD_VERSION);
    bar.setAttribute('aria-label', 'Composer context');

    const pillStyle = 'display:inline-flex;align-items:center;gap:6px;padding:3px 8px;border-radius:6px;background:transparent;color:inherit;font-size:13px;';
    const btnStyle = pillStyle + 'border:1px solid transparent;cursor:pointer;outline:none;transition:background 0.15s ease;';

    // 1. Project Selector Button (acts like the live one and includes select indicator)
    const project = document.createElement('button');
    project.type = 'button';
    project.setAttribute(PROJECT_BTN_ATTR, 'true');
    project.setAttribute('style', btnStyle);
    project.setAttribute('aria-label', 'Select project');
    project.title = 'Switch workspace / project';
    project.appendChild(createProjectFolderIcon());
    const projectText = document.createElement('span');
    projectText.setAttribute(PROJECT_VAL_ATTR, 'true');
    projectText.style.fontWeight = '600';
    projectText.textContent = currentProjectName();
    project.appendChild(projectText);
    const chevron = createChevronDownIcon();
    chevron.setAttribute(CHEVRON_ATTR, 'true');
    project.appendChild(chevron);

    project.addEventListener('mouseenter', () => {
      if (isNewChat()) {
        project.style.background = 'rgba(128, 128, 128, 0.18)';
      }
    });
    project.addEventListener('mouseleave', () => {
      project.style.background = 'transparent';
    });
    project.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (isNewChat()) {
        triggerProjectSelect(project);
      }
    });

    // 2. Location (Local)
    const location = document.createElement('span');
    location.setAttribute('style', pillStyle);
    location.appendChild(createLocationIcon());
    const locationText = document.createElement('span');
    locationText.textContent = 'Local';
    location.appendChild(locationText);

    // 3. Branch
    const branch = document.createElement('span');
    branch.setAttribute('style', pillStyle);
    branch.appendChild(createBranchIcon());
    const branchText = document.createElement('span');
    branchText.setAttribute(BRANCH_VAL_ATTR, 'true');
    branchText.textContent = currentBranchName();
    branch.appendChild(branchText);

    // 4. Background Process Pill (Icon + Number)
    const processBadge = document.createElement('span');
    processBadge.setAttribute(PROCESS_BADGE_ATTR, 'true');
    processBadge.appendChild(createProcessIcon());
    const processCountText = document.createElement('span');
    processCountText.setAttribute(PROCESS_COUNT_ATTR, 'true');
    const runningCount = getRunningProcessCount();
    processCountText.textContent = String(runningCount);
    processBadge.appendChild(processCountText);
    processBadge.title = runningCount + ' background process' + (runningCount === 1 ? '' : 'es') + ' running in this session';
    if (runningCount === 0) {
      processBadge.style.display = 'none';
    }

    // 5. New Chat Button
    const newChat = document.createElement('button');
    newChat.type = 'button';
    newChat.setAttribute(NEW_CHAT_BTN_ATTR, 'true');
    newChat.setAttribute('style', btnStyle);
    newChat.setAttribute('aria-label', 'New chat');
    newChat.title = 'Start a new chat in this workspace';
    newChat.appendChild(createNewChatIcon());
    const newChatText = document.createElement('span');
    newChatText.textContent = 'New chat';
    newChat.appendChild(newChatText);

    newChat.addEventListener('mouseenter', () => {
      newChat.style.background = 'rgba(128, 128, 128, 0.18)';
    });
    newChat.addEventListener('mouseleave', () => {
      newChat.style.background = 'transparent';
    });
    newChat.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      triggerNewChat();
    });

    // 6. Commit Button
    const commit = document.createElement('button');
    commit.type = 'button';
    commit.setAttribute(COMMIT_BTN_ATTR, 'true');
    commit.setAttribute('style', btnStyle);
    commit.setAttribute('aria-label', 'Commit');
    commit.title = 'Commit changes';
    commit.appendChild(createCommitIcon());
    const commitText = document.createElement('span');
    commitText.textContent = 'Commit';
    commit.appendChild(commitText);

    commit.addEventListener('mouseenter', () => {
      if (!commit.disabled) commit.style.background = 'rgba(128, 128, 128, 0.18)';
    });
    commit.addEventListener('mouseleave', () => {
      commit.style.background = 'transparent';
    });
    commit.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (!commit.disabled) triggerCommitAction();
    });

    // 7. Push Button
    const push = document.createElement('button');
    push.type = 'button';
    push.setAttribute(PUSH_BTN_ATTR, 'true');
    push.setAttribute('style', btnStyle);
    push.setAttribute('aria-label', 'Push');
    push.title = 'Push changes';
    push.appendChild(createPushIcon());
    const pushText = document.createElement('span');
    pushText.textContent = 'Push';
    push.appendChild(pushText);

    push.addEventListener('mouseenter', () => {
      if (!push.disabled) push.style.background = 'rgba(128, 128, 128, 0.18)';
    });
    push.addEventListener('mouseleave', () => {
      push.style.background = 'transparent';
    });
    push.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (!push.disabled) triggerPushAction();
    });

    // 8. Git Actions Group (Right-aligned)
    const gitGroup = document.createElement('div');
    gitGroup.setAttribute(GIT_GROUP_ATTR, 'true');
    gitGroup.setAttribute('style', 'display:inline-flex;align-items:center;gap:6px;margin-inline-start:auto;');
    gitGroup.append(commit, push);

    bar.append(project, location, branch, processBadge, newChat, gitGroup);
    syncProjectElement(bar);
    syncGitActionButtons(bar);
    return bar;
  }

  function findComposerAnchor() {
    const inputs = Array.from(document.querySelectorAll('[contenteditable="true"], textarea'))
      .filter((el) => {
        const r = el.getBoundingClientRect();
        return r.height > 0 && r.width > 0;
      });

    if (inputs.length === 0) return null;

    const activeInput = inputs.reduce((lowest, el) => {
      if (!lowest) return el;
      return el.getBoundingClientRect().top > lowest.getBoundingClientRect().top ? el : lowest;
    }, null);

    if (!activeInput) return null;

    const card = activeInput.closest('.bg-card-border')
      || activeInput.closest('.bg-card')
      || activeInput.closest('form')
      || activeInput.parentElement?.parentElement?.parentElement
      || activeInput.parentElement;

    if (card && card.parentElement) {
      return { container: card.parentElement, insertBefore: card };
    }

    return null;
  }

  function syncProcessBadge(bar) {
    if (!bar) return;
    const badge = bar.querySelector('[' + PROCESS_BADGE_ATTR + ']');
    const countEl = bar.querySelector('[' + PROCESS_COUNT_ATTR + ']');
    if (!badge || !countEl) return;

    const count = getRunningProcessCount();
    countEl.textContent = String(count);
    badge.title = count + ' background process' + (count === 1 ? '' : 'es') + ' running in this session';
    badge.style.display = count > 0 ? 'inline-flex' : 'none';

    // Hide bulky process cards in the above-composer container if present
    const aboveComposer = bar.previousElementSibling;
    if (aboveComposer && aboveComposer.children.length > 0) {
      Array.from(aboveComposer.children).forEach((child) => {
        if (!child.hasAttribute(TOP_BAR_ATTR)) {
          const text = (child.textContent || '').toLowerCase();
          const testId = (child.getAttribute('data-testid') || '').toLowerCase();
          const cls = (child.className || '').toString().toLowerCase();
          const isProcess = testId.includes('process') || testId.includes('task') ||
                            cls.includes('process') || cls.includes('task') ||
                            text.includes('background') || text.includes('running') ||
                            child.querySelector('.animate-spin, button[aria-label*="Stop" i]') !== null;
          if (isProcess) {
            child.setAttribute('data-gemini-plus-hide-bulky-process', 'true');
          }
        }
      });
    }
  }

  function syncGitActionButtons(bar) {
    if (!bar) return;
    const gitGroup = bar.querySelector('[' + GIT_GROUP_ATTR + ']');
    const commitBtn = bar.querySelector('[' + COMMIT_BTN_ATTR + ']');
    const pushBtn = bar.querySelector('[' + PUSH_BTN_ATTR + ']');
    if (!commitBtn && !pushBtn) return;

    const gitStates = getGitActionStates();
    if (commitBtn) {
      if (gitStates.commit && gitStates.commit.available) {
        commitBtn.style.display = 'inline-flex';
        commitBtn.disabled = Boolean(gitStates.commit.disabled);
        commitBtn.title = gitStates.commit.disabled ? 'No changes to commit' : 'Commit changes';
      } else {
        commitBtn.style.display = 'none';
      }
    }
    if (pushBtn) {
      if (gitStates.push && gitStates.push.available) {
        pushBtn.style.display = 'inline-flex';
        pushBtn.disabled = Boolean(gitStates.push.disabled);
        pushBtn.title = gitStates.push.disabled ? 'No commits to push' : 'Push changes';
      } else {
        pushBtn.style.display = 'none';
      }
    }
    if (gitGroup) {
      const anyGitVisible = Boolean(
        (gitStates.commit && gitStates.commit.available) ||
        (gitStates.push && gitStates.push.available)
      );
      gitGroup.style.display = anyGitVisible ? 'inline-flex' : 'none';
    }
  }

  function installComposerTopBar() {
    ensureStyles();
    const anchor = findComposerAnchor();
    if (!anchor || !anchor.container) return;

    let existingBar = document.querySelector('[' + TOP_BAR_ATTR + ']');
    if (existingBar && existingBar.getAttribute('data-gemini-plus-version') !== BUILD_VERSION) {
      existingBar.remove();
      existingBar = null;
    }

    if (existingBar) {
      syncProjectElement(existingBar);

      const branchLabel = existingBar.querySelector('[' + BRANCH_VAL_ATTR + ']');
      if (branchLabel) branchLabel.textContent = currentBranchName();

      syncProcessBadge(existingBar);
      syncGitActionButtons(existingBar);

      if (existingBar.nextSibling !== anchor.insertBefore && existingBar !== anchor.insertBefore) {
        anchor.container.insertBefore(existingBar, anchor.insertBefore);
      }
      return;
    }

    const newBar = createComposerTopBar();
    anchor.container.insertBefore(newBar, anchor.insertBefore);
  }

  let pending = false;
  const schedule = () => {
    if (pending) return;
    pending = true;
    window.setTimeout(() => {
      pending = false;
      installComposerTopBar();
    }, 60);
  };

  const observer = new MutationObserver(schedule);
  observer.observe(document.documentElement, { childList: true, subtree: true });

  window.__GEMINI_PLUS_COMPOSER_TOP_BAR = {
    install: installComposerTopBar,
    setProcessCount(count) {
      window.__ANTIGRAVITY_PLUS_RUNNING_PROCESSES_COUNT = count;
      schedule();
    },
    observer
  };

  installComposerTopBar();
  console.log('[Antigravity Plus] Composer Top Bar installed with background process badge.');
})();
'@
}
