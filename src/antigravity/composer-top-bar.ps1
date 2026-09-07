function Get-AntigravityComposerTopBarPayload {
    @'
(function () {
  const TOP_BAR_ATTR = 'data-gemini-plus-composer-top-bar';
  const NEW_CHAT_BTN_ATTR = 'data-gemini-plus-composer-new-chat';
  const COMMIT_BTN_ATTR = 'data-gemini-plus-composer-commit';
  const PUSH_BTN_ATTR = 'data-gemini-plus-composer-push';
  const BRANCH_VAL_ATTR = 'data-gemini-plus-composer-branch';
  const PROJECT_VAL_ATTR = 'data-gemini-plus-composer-project';
  const PROCESS_BADGE_ATTR = 'data-gemini-plus-composer-process';
  const PROCESS_COUNT_ATTR = 'data-gemini-plus-process-count';
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

      [data-gemini-plus-composer-top-bar] + * .bg-card,
      [data-gemini-plus-composer-top-bar] + * [class*="rounded"] {
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
      const text = (b.innerText || '').trim();
      return text === 'Push' || text === 'Commit';
    });

    let mtFiber = null;
    if (vcsBtn) {
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
    }

    if (mtFiber && mtFiber.memoizedProps) {
      const props = mtFiber.memoizedProps;
      const mainLabel = (vcsBtn ? vcsBtn.innerText : '').trim() || 'Push';
      const mainDisabled = Boolean(props.disabled);
      const mainHandler = typeof props.onMainClick === 'function' ? props.onMainClick : null;

      const other = (props.actions || [])[0];
      const otherLabel = other ? (typeof other.label === 'string' ? other.label : String(other.label)).trim() : (mainLabel === 'Push' ? 'Commit' : 'Push');
      const otherDisabled = other ? Boolean(other.disabled || props.disabled) : true;
      const otherHandler = other && typeof other.onSelect === 'function' ? other.onSelect : null;

      const isCommitMain = mainLabel.toLowerCase().includes('commit');
      return {
        commit: {
          label: 'Commit',
          disabled: isCommitMain ? mainDisabled : otherDisabled,
          run: isCommitMain ? mainHandler : otherHandler
        },
        push: {
          label: 'Push',
          disabled: isCommitMain ? otherDisabled : mainDisabled,
          run: isCommitMain ? otherHandler : mainHandler
        }
      };
    }

    return {
      commit: { label: 'Commit', disabled: false, run: null },
      push: { label: 'Push', disabled: false, run: null }
    };
  }

  function triggerNewChat() {
    const candidates = [
      'button[data-testid="new-conversation-button"]',
      'button[data-testid="new-task-button"]',
      'button[data-testid="new-chat-button"]',
      'button[aria-label*="New Chat" i]',
      'button[aria-label*="New conversation" i]',
      'button[aria-label*="New task" i]',
      'button[title*="New Chat" i]',
      'button[title*="New conversation" i]',
      'button[title*="New task" i]'
    ];
    for (const sel of candidates) {
      const btn = document.querySelector(sel);
      if (btn && btn.offsetParent !== null) {
        btn.click();
        return;
      }
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-new-chat'));
  }

  function triggerCommitAction() {
    const states = getGitActionStates();
    if (typeof states.commit.run === 'function') {
      try {
        states.commit.run();
        console.log('[Antigravity Plus] Native Commit action executed');
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] Native Commit execution error:', e);
      }
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-commit'));
  }

  function triggerPushAction() {
    const states = getGitActionStates();
    if (typeof states.push.run === 'function') {
      try {
        states.push.run();
        console.log('[Antigravity Plus] Native Push action executed');
        return;
      } catch (e) {
        console.warn('[Antigravity Plus] Native Push execution error:', e);
      }
    }
    window.dispatchEvent(new CustomEvent('antigravity-plus-push'));
  }

  function createComposerTopBar() {
    const bar = document.createElement('div');
    bar.setAttribute(TOP_BAR_ATTR, 'true');
    bar.setAttribute('aria-label', 'Composer context');

    const pillStyle = 'display:inline-flex;align-items:center;gap:6px;padding:3px 8px;border-radius:6px;background:transparent;color:inherit;font-size:13px;';
    const btnStyle = pillStyle + 'border:1px solid transparent;cursor:pointer;outline:none;transition:background 0.15s ease;';

    // 1. Project
    const project = document.createElement('span');
    project.setAttribute('style', pillStyle);
    project.appendChild(createProjectFolderIcon());
    const projectText = document.createElement('span');
    projectText.setAttribute(PROJECT_VAL_ATTR, 'true');
    projectText.style.fontWeight = '600';
    projectText.textContent = currentProjectName();
    project.appendChild(projectText);

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

    // 6. Commit Button (Right-aligned)
    const commit = document.createElement('button');
    commit.type = 'button';
    commit.setAttribute(COMMIT_BTN_ATTR, 'true');
    commit.setAttribute('style', btnStyle + 'margin-inline-start:auto;');
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

    bar.append(project, location, branch, processBadge, newChat, commit, push);
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
    const commitBtn = bar.querySelector('[' + COMMIT_BTN_ATTR + ']');
    const pushBtn = bar.querySelector('[' + PUSH_BTN_ATTR + ']');
    if (!commitBtn && !pushBtn) return;

    const gitStates = getGitActionStates();
    if (commitBtn) {
      commitBtn.disabled = gitStates.commit.disabled;
      commitBtn.title = gitStates.commit.disabled ? 'No changes to commit' : 'Commit changes';
    }
    if (pushBtn) {
      pushBtn.disabled = gitStates.push.disabled;
      pushBtn.title = gitStates.push.disabled ? 'No commits to push' : 'Push changes';
    }
  }

  function installComposerTopBar() {
    ensureStyles();
    const anchor = findComposerAnchor();
    if (!anchor || !anchor.container) return;

    let existingBar = document.querySelector('[' + TOP_BAR_ATTR + ']');
    if (existingBar && !existingBar.querySelector('[' + PUSH_BTN_ATTR + ']')) {
      existingBar.remove();
      existingBar = null;
    }

    if (existingBar) {
      const projectLabel = existingBar.querySelector('[' + PROJECT_VAL_ATTR + ']');
      if (projectLabel) projectLabel.textContent = currentProjectName();

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
