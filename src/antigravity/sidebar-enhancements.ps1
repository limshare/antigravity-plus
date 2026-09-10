function Get-AntigravitySidebarEnhancementsPayload {
    @'
(function () {
  const SYNTHETIC_SECTION_ATTR = 'data-gemini-plus-synthetic-section';
  const SYNTHETIC_ROW_ATTR = 'data-gemini-plus-synthetic-row';
  const RECENTS_KEY = 'antigravity_plus_recents_collapsed';
  const RECENTS_LOADED_KEY = 'antigravity_plus_recents_loaded';
  const RECENTS_PAGE_SIZE = 3;
  const RECENTS_MIN_VISIBLE = 3;
  const PROJECT_STATES_KEY = 'antigravity_plus_sidebar_project_states';
  const SECTION_STATES_KEY = 'antigravity_plus_sidebar_section_states';
  const PROJECT_MAP_KEY = 'antigravity_plus_project_names';
  const CATALOG_KEY = 'antigravity_plus_thread_catalog';
  const UNREAD_KEY = 'antigravity_plus_unread_threads';
  const WORKING_KEY = 'antigravity_plus_working_threads';

  if (window.__GEMINI_PLUS_SIDEBAR_ENHANCEMENTS && window.__GEMINI_PLUS_SIDEBAR_ENHANCEMENTS.observer) {
    try { window.__GEMINI_PLUS_SIDEBAR_ENHANCEMENTS.observer.disconnect(); } catch (e) {}
  }

  const INSTANCE_ID = (window.__GEMINI_PLUS_SIDEBAR_INSTANCE = (window.__GEMINI_PLUS_SIDEBAR_INSTANCE || 0) + 1);

  // 1. Terminology Renaming:
  // Top Sidebar Buttons: New Conversation -> New Chat, Conversation History -> History
  // Section Headers: Pinned Conversations -> Pinned, Conversations -> Tasks
  // Action Buttons & Tooltips: New Conversation in Project -> New Chat in Project, Pin conversation -> Pin, Archive conversation -> Archive
  const TERMINOLOGY_MAP = [
    { pattern: /\bNew Conversation in Project\b/gi, replacement: 'New Chat in Project' },
    { pattern: /\bNew Task in Project\b/gi, replacement: 'New Chat in Project' },
    { pattern: /\bNew conversation in project\b/gi, replacement: 'New Chat in Project' },
    { pattern: /\bNew Conversation\b/gi, replacement: 'New Chat' },
    { pattern: /\bNew Task\b/gi, replacement: 'New Chat' },
    { pattern: /\bConversation History\b/gi, replacement: 'History' },
    { pattern: /\bTask History\b/gi, replacement: 'History' },
    { pattern: /\bPinned Conversations\b/gi, replacement: 'Pinned' },
    { pattern: /\bPinned Tasks\b/gi, replacement: 'Pinned' },
    { pattern: /\bUnpin conversation\b/gi, replacement: 'Unpin' },
    { pattern: /\bUnpin task\b/gi, replacement: 'Unpin' },
    { pattern: /\bPin conversation\b/gi, replacement: 'Pin' },
    { pattern: /\bPin task\b/gi, replacement: 'Pin' },
    { pattern: /\bUnarchive conversation\b/gi, replacement: 'Unarchive' },
    { pattern: /\bUnarchive task\b/gi, replacement: 'Unarchive' },
    { pattern: /\bArchive conversation\b/gi, replacement: 'Archive' },
    { pattern: /\bArchive task\b/gi, replacement: 'Archive' },
    { pattern: /\bConversations\b/g, replacement: 'Tasks' },
    { pattern: /\bconversations\b/g, replacement: 'tasks' },
    { pattern: /\bConversation\b/g, replacement: 'Task' },
    { pattern: /\bconversation\b/g, replacement: 'task' }
  ];

  function replaceText(text) {
    if (!text || typeof text !== 'string') return text;
    let res = text;
    for (const { pattern, replacement } of TERMINOLOGY_MAP) {
      res = res.replace(pattern, replacement);
    }
    return res;
  }

  function applyTerminology(root) {
    if (!root) return;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        if (!node || !node.nodeValue) return NodeFilter.FILTER_REJECT;
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;
        if (parent.closest('[' + SYNTHETIC_SECTION_ATTR + ']') || parent.closest('.monaco-editor') || parent.closest('[data-testid="conversation-view"]')) {
          return NodeFilter.FILTER_REJECT;
        }
        if (/conversation|chat|task|pinned|pin|archive|history/i.test(node.nodeValue)) {
          return NodeFilter.FILTER_ACCEPT;
        }
        return NodeFilter.FILTER_SKIP;
      }
    });

    const nodesToUpdate = [];
    while (walker.nextNode()) {
      nodesToUpdate.push(walker.currentNode);
    }

    nodesToUpdate.forEach(node => {
      const next = replaceText(node.nodeValue);
      if (next !== node.nodeValue) node.nodeValue = next;
    });

    const selector = [
      '[aria-label*="onversation" i]', '[aria-label*="task" i]', '[aria-label*="chat" i]', '[aria-label*="pin" i]', '[aria-label*="archive" i]', '[aria-label*="history" i]',
      '[title*="onversation" i]', '[title*="task" i]', '[title*="chat" i]', '[title*="pin" i]', '[title*="archive" i]', '[title*="history" i]',
      '[data-title*="onversation" i]', '[data-title*="task" i]', '[data-title*="chat" i]', '[data-title*="pinned" i]',
      '[placeholder*="onversation" i]', '[placeholder*="task" i]', '[placeholder*="chat" i]',
      '[data-tooltip*="onversation" i]', '[data-tooltip*="task" i]', '[data-tooltip*="chat" i]', '[data-tooltip*="pin" i]', '[data-tooltip*="archive" i]'
    ].join(',');

    const elementsWithAttributes = root.querySelectorAll ? root.querySelectorAll(selector) : [];
    elementsWithAttributes.forEach(el => {
      ['aria-label', 'title', 'data-title', 'placeholder', 'data-tooltip'].forEach(attr => {
        const val = el.getAttribute(attr);
        if (val) {
          const next = replaceText(val);
          if (next !== val) el.setAttribute(attr, next);
        }
      });
    });
  }

  // 2. Open States Tracking and Restoration (Projects and Sections per-window)
  function getSavedProjectStates() {
    try {
      return JSON.parse(sessionStorage.getItem(PROJECT_STATES_KEY) || '{}');
    } catch (e) {
      return {};
    }
  }

  function saveProjectState(projectName, isExpanded) {
    if (!projectName) return;
    try {
      const states = getSavedProjectStates();
      states[projectName] = Boolean(isExpanded);
      sessionStorage.setItem(PROJECT_STATES_KEY, JSON.stringify(states));
    } catch (e) {}
  }

  function getSavedSectionStates() {
    try {
      return JSON.parse(sessionStorage.getItem(SECTION_STATES_KEY) || '{}');
    } catch (e) {
      return {};
    }
  }

  function saveSectionState(sectionTitle, isExpanded) {
    if (!sectionTitle) return;
    try {
      const states = getSavedSectionStates();
      states[sectionTitle] = Boolean(isExpanded);
      sessionStorage.setItem(SECTION_STATES_KEY, JSON.stringify(states));
    } catch (e) {}
  }

  function getCachedProjectMap() {
    try {
      return new Map(Object.entries(JSON.parse(localStorage.getItem(PROJECT_MAP_KEY) || '{}')));
    } catch (e) {
      return new Map();
    }
  }

  function saveCachedProjectMap(map) {
    try {
      const obj = {};
      map.forEach((v, k) => { obj[k] = v; });
      localStorage.setItem(PROJECT_MAP_KEY, JSON.stringify(obj));
    } catch (e) {}
  }

  function getThreadCatalog() {
    const catalogMap = new Map();
    try {
      const saved = JSON.parse(localStorage.getItem(CATALOG_KEY) || '[]');
      if (Array.isArray(saved)) {
        saved.forEach(item => {
          if (item && item.cascadeId) catalogMap.set(item.cascadeId, item);
        });
      }
    } catch (e) {}
    return catalogMap;
  }

  function saveThreadCatalog(catalogMap) {
    try {
      localStorage.setItem(CATALOG_KEY, JSON.stringify(Array.from(catalogMap.values())));
    } catch (e) {}
  }

  let isRestoringStates = false;
  const userActionTimes = new Map();
  const restoredCards = new WeakSet();
  const restoredSections = new WeakSet();

  function restoreOpenStates() {
    if (isRestoringStates) return;
    isRestoringStates = true;
    try {
      const now = Date.now();
      const savedProjects = getSavedProjectStates();
      const projectCards = document.querySelectorAll('button[data-project-card="true"]');
      projectCards.forEach(card => {
        const name = (card.innerText || '').trim();
        if (!name) return;

        // Skip if user recently clicked this project
        const lastUserAction = userActionTimes.get(name) || 0;
        if (now - lastUserAction < 2000) {
          restoredCards.add(card);
          return;
        }

        // Each card DOM element only needs auto-restoration once upon mounting
        if (restoredCards.has(card)) return;
        restoredCards.add(card);

        if (!(name in savedProjects)) return;
        const shouldBeExpanded = Boolean(savedProjects[name]);
        const isCurrentlyExpanded = card.getAttribute('aria-expanded') === 'true';

        if (shouldBeExpanded !== isCurrentlyExpanded) {
          try { card.click(); } catch(e) {}
        }
      });

      const savedSections = getSavedSectionStates();
      const sectionHeaders = document.querySelectorAll('[data-testid="section-header"]');
      sectionHeaders.forEach(sh => {
        const title = (sh.getAttribute('data-title') || sh.innerText || '').trim();
        const cleanTitle = replaceText(title);
        if (!cleanTitle) return;
        const btn = sh.querySelector('button');
        if (!btn) return;

        // Skip if user recently clicked this section
        const lastUserAction = userActionTimes.get(cleanTitle) || 0;
        if (now - lastUserAction < 2000) {
          restoredSections.add(btn);
          return;
        }

        // Each section button DOM element only needs auto-restoration once upon mounting
        if (restoredSections.has(btn)) return;
        restoredSections.add(btn);

        if (!(cleanTitle in savedSections)) return;
        const shouldBeExpanded = Boolean(savedSections[cleanTitle]);
        const isCurrentlyExpanded = btn.getAttribute('aria-expanded') === 'true';

        if (shouldBeExpanded !== isCurrentlyExpanded) {
          try { btn.click(); } catch(e) {}
        }
      });
    } finally {
      isRestoringStates = false;
    }
  }

  // Global click listener to track user project/section expansion
  document.addEventListener('click', (e) => {
    if (window.__GEMINI_PLUS_SIDEBAR_INSTANCE !== INSTANCE_ID) return;
    if (isRestoringStates) return;
    const target = e.target;
    if (!target) return;

    const projectCard = target.closest('button[data-project-card="true"]');
    if (projectCard) {
      const name = (projectCard.innerText || '').trim();
      if (name) {
        const wasExpanded = projectCard.getAttribute('aria-expanded') === 'true';
        const nextExpanded = !wasExpanded;
        userActionTimes.set(name, Date.now());
        saveProjectState(name, nextExpanded);
        restoredCards.add(projectCard);
        setTimeout(() => {
          const actualExpanded = projectCard.getAttribute('aria-expanded') === 'true';
          saveProjectState(name, actualExpanded);
        }, 150);
      }
      return;
    }

    const sectionBtn = target.closest('[data-testid="section-header"] button');
    if (sectionBtn) {
      const sh = sectionBtn.closest('[data-testid="section-header"]');
      const title = (sh?.getAttribute('data-title') || sh?.innerText || '').trim();
      const cleanTitle = replaceText(title);
      if (cleanTitle) {
        const wasExpanded = sectionBtn.getAttribute('aria-expanded') === 'true';
        const nextExpanded = !wasExpanded;
        userActionTimes.set(cleanTitle, Date.now());
        saveSectionState(cleanTitle, nextExpanded);
        restoredSections.add(sectionBtn);
        setTimeout(() => {
          const actualExpanded = sectionBtn.getAttribute('aria-expanded') === 'true';
          saveSectionState(cleanTitle, actualExpanded);
        }, 150);
      }
      return;
    }
  }, true);

  // 3. Unread Notifier & Working Rotating Spinner Helpers
  function getUnreadThreads() {
    try {
      return new Set(JSON.parse(localStorage.getItem(UNREAD_KEY) || '[]'));
    } catch (e) {
      return new Set();
    }
  }

  function saveUnreadThreads(set) {
    try {
      localStorage.setItem(UNREAD_KEY, JSON.stringify(Array.from(set)));
    } catch (e) {}
  }

  function getWorkingThreads() {
    try {
      return new Set(JSON.parse(localStorage.getItem(WORKING_KEY) || '[]'));
    } catch (e) {
      return new Set();
    }
  }

  function saveWorkingThreads(set) {
    try {
      localStorage.setItem(WORKING_KEY, JSON.stringify(Array.from(set)));
    } catch (e) {}
  }

  function createThreadSpinnerGraphic() {
    return `
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" class="shrink-0" xmlns="http://www.w3.org/2000/svg">
        <path opacity="0.3" d="M18 12C18 8.68629 15.3137 6 12 6C8.68629 6 6 8.68629 6 12C6 15.3137 8.68629 18 12 18C15.3137 18 18 18 18 12ZM20 12C20 16.4183 16.4183 20 12 20C7.58172 20 4 16.4183 4 12C4 7.58172 7.58172 4 12 4C16.4183 4 20 7.58172 20 12Z" fill="currentColor"></path>
        <path d="M12 4C16.4183 4 20 7.58172 20 12C20 16.4183 16.4183 20 12 20C7.58172 20 4 16.4183 4 12H6C6 15.3137 8.68629 18 12 18C15.3137 18 18 15.3137 18 12C18 8.68629 15.3137 6 12 6V4Z" fill="currentColor"></path>
      </svg>
    `;
  }

  function getSpinnerHtml() {
    return `
      <div data-gemini-plus-thread-spinner="true" class="inline-flex items-center justify-center shrink-0 ml-1 text-primary/80 animate-spin" style="animation-duration: 1200ms;" title="Task is running">
        ${createThreadSpinnerGraphic()}
      </div>
    `;
  }

  function getUnreadDotHtml() {
    return `
      <span data-gemini-plus-thread-unread="true" class="inline-block w-2 h-2 rounded-full shrink-0 ml-1" style="background-color: #3b82f6; box-shadow: 0 0 5px rgba(59, 130, 246, 0.7);" title="Unread response"></span>
    `;
  }

  function syncActiveTaskStatus() {
    const currentPath = window.location.pathname || '';
    const match = currentPath.match(/\/c\/([0-9a-f-]+)/i);
    const activeCascadeId = match ? match[1] : null;

    const workingSet = getWorkingThreads();
    const unreadSet = getUnreadThreads();
    let unreadChanged = false;
    let workingChanged = false;

    // If user is currently viewing activeCascadeId, clear unread dot
    if (activeCascadeId && unreadSet.has(activeCascadeId)) {
      unreadSet.delete(activeCascadeId);
      unreadChanged = true;
    }

    // Detect if current view is generating
    const isGenerating = Boolean(
      document.querySelector('button[aria-label*="Stop" i]') ||
      document.querySelector('button[aria-label*="Cancel" i]') ||
      document.querySelector('[data-testid="stop-button"]') ||
      document.querySelector('button[aria-label="Stop generating"]')
    );

    if (activeCascadeId) {
      if (isGenerating && !workingSet.has(activeCascadeId)) {
        workingSet.add(activeCascadeId);
        workingChanged = true;
      } else if (!isGenerating && workingSet.has(activeCascadeId)) {
        workingSet.delete(activeCascadeId);
        workingChanged = true;
      }
    }

    if (unreadChanged) saveUnreadThreads(unreadSet);
    if (workingChanged) saveWorkingThreads(workingSet);
  }

  function syncNativeRowIndicators() {
    const unreadSet = getUnreadThreads();
    const workingSet = getWorkingThreads();
    const nativeRows = document.querySelectorAll('[data-testid="conversation-row-sidebar"]');
    nativeRows.forEach(row => {
      let cascadeId = row.getAttribute('data-cascade-id');
      if (!cascadeId) {
        const parent = row.closest('[data-cascade-id]') || row.querySelector('[data-cascade-id]') || row.querySelector('a[href*="/c/"]');
        const href = parent?.getAttribute('href') || row.querySelector('a')?.getAttribute('href') || row.closest('a')?.getAttribute('href');
        cascadeId = parent?.getAttribute('data-cascade-id') || href?.match(/\/c\/([0-9a-f-]+)/i)?.[1];
      }
      if (!cascadeId) {
        const fiberKey = Object.keys(row).find(k => k.startsWith('__reactFiber$'));
        if (fiberKey) {
          let fiber = row[fiberKey];
          while (fiber && !cascadeId) {
            if (fiber.memoizedProps) {
              if (fiber.memoizedProps.cascadeId) cascadeId = fiber.memoizedProps.cascadeId;
              else if (fiber.memoizedProps.item?.cascadeId) cascadeId = fiber.memoizedProps.item.cascadeId;
              else if (fiber.memoizedProps.conversation?.cascadeId) cascadeId = fiber.memoizedProps.conversation.cascadeId;
              else if (fiber.memoizedProps.id && /^[0-9a-f-]{36}$/i.test(fiber.memoizedProps.id)) cascadeId = fiber.memoizedProps.id;
            }
            fiber = fiber.return;
          }
        }
      }
      if (!cascadeId) return;

      const isWorking = workingSet.has(cascadeId);
      const isUnread = !isWorking && unreadSet.has(cascadeId);

      let spinner = row.querySelector('[data-gemini-plus-thread-spinner="true"]');
      let unread = row.querySelector('[data-gemini-plus-thread-unread="true"]');

      if (isWorking) {
        if (unread) unread.remove();
        if (!spinner) {
          const spinEl = document.createElement('div');
          spinEl.innerHTML = getSpinnerHtml();
          const target = spinEl.firstElementChild;
          row.appendChild(target);
        }
      } else {
        if (spinner) spinner.remove();
        if (isUnread) {
          if (!unread) {
            const dotEl = document.createElement('div');
            dotEl.innerHTML = getUnreadDotHtml();
            const target = dotEl.firstElementChild;
            row.appendChild(target);
          }
        } else {
          if (unread) unread.remove();
        }
      }
    });
  }

  // 4. Synthetic Recents Section (Persistent across open/closed project states)
  function formatRelativeTime(ms) {
    if (!ms) return '';
    const diffMs = Date.now() - ms;
    if (diffMs < 0) return 'now';
    const mins = Math.floor(diffMs / (1000 * 60));
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const months = Math.floor(days / 30);

    if (mins < 60) return (mins <= 1 ? '1m' : mins + 'm');
    if (hours < 24) return hours + 'h';
    if (days < 30) return days + 'd';
    return months + 'mo';
  }

  function getRecents(sidebarEl) {
    const catalogMap = getThreadCatalog();
    const projectMap = getCachedProjectMap();

    if (sidebarEl) {
      const fiberKey = Object.keys(sidebarEl).find(k => k.startsWith('__reactFiber$'));
      if (fiberKey) {
        let fiber = sidebarEl[fiberKey];
        let items = null;
        while (fiber) {
          if (fiber.memoizedProps && fiber.memoizedProps.items) {
            items = fiber.memoizedProps.items;
            break;
          }
          fiber = fiber.return;
        }

        if (items && Array.isArray(items)) {
          items.forEach(item => {
            if (item.type === 'header' && item.label && item.id) {
              const cleanId = item.id.replace(/^header-/, '');
              projectMap.set(cleanId, item.label);
              projectMap.set(item.id, item.label);
            }
            if (item.type === 'project' && item.name) {
              projectMap.set(item.id || item.projectId, item.name);
            }
          });

          document.querySelectorAll('button[data-project-card="true"]').forEach(btn => {
            const name = (btn.innerText || '').trim();
            const parent = btn.closest('[data-cascade-id]') || btn.closest('[data-project-id]');
            const id = parent?.getAttribute('data-project-id');
            if (id && name) projectMap.set(id, name);
          });

          saveCachedProjectMap(projectMap);

          const rows = items.filter(i => i.type === 'row' && i.cascadeId);
          rows.forEach(r => {
            const s = r.summary || {};
            const seconds = Number(s.lastModifiedTime?.seconds || s.createdTime?.seconds || 0);
            const nanos = Number(s.lastModifiedTime?.nanos || s.createdTime?.nanos || 0);
            const lastModifiedMs = (seconds * 1000) + Math.round(nanos / 1000000);
            const projectId = s.trajectoryMetadata?.projectId || r.groupId;
            const rawProjectName = projectId ? projectMap.get(projectId) : null;
            const projectName = (rawProjectName && !/^[0-9a-f-]{36}$/i.test(rawProjectName)) ? rawProjectName : null;
            const title = s.summary || s.annotations?.title || 'Untitled Task';

            if (title && lastModifiedMs > 0) {
              const existing = catalogMap.get(r.cascadeId);
              catalogMap.set(r.cascadeId, {
                cascadeId: r.cascadeId,
                title,
                lastModifiedMs: Math.max(existing?.lastModifiedMs || 0, lastModifiedMs),
                projectName: projectName || existing?.projectName || null
              });
            }
          });

          saveThreadCatalog(catalogMap);
        }
      }
    }

    const allTasks = Array.from(catalogMap.values()).map(t => {
      let resolvedProject = t.projectName;
      if (!resolvedProject || /^[0-9a-f-]{36}$/i.test(resolvedProject)) {
        resolvedProject = projectMap.get(resolvedProject) || null;
      }
      return {
        ...t,
        projectName: resolvedProject,
        relativeTime: formatRelativeTime(t.lastModifiedMs)
      };
    });

    allTasks.sort((a, b) => b.lastModifiedMs - a.lastModifiedMs);
    return allTasks;
  }

  const PROJECT_PAGE_SIZE = 3;
  const PROJECT_LOADED_PREFIX = 'antigravity_plus_proj_loaded_';
  const SYNTHETIC_PROJ_PAGER_ATTR = 'data-gemini-plus-project-pager';

  function layoutSidebarVirtualizer(inner, section) {
    if (!inner || !section) return;

    const isCollapsed = sessionStorage.getItem(RECENTS_KEY) === 'true';
    const list = section.querySelector('.gemini-plus-recents-list');
    if (list) {
      list.style.display = isCollapsed ? 'none' : 'flex';
    }

    const virtualItems = Array.from(inner.querySelectorAll(':scope > [data-index]'));
    if (virtualItems.length === 0) return;

    virtualItems.sort((a, b) => parseInt(a.getAttribute('data-index'), 10) - parseInt(b.getAttribute('data-index'), 10));

    // Find projects header index
    let projectsHeaderIdx = -1;
    virtualItems.forEach((el, idx) => {
      const sh = el.querySelector('[data-testid="section-header"]');
      if (sh && /projects/i.test(sh.getAttribute('data-title') || sh.innerText || '')) {
        projectsHeaderIdx = idx;
      }
    });

    // 1. Group tasks per project and identify native see-all buttons
    const projectTasks = new Map();
    const projectNativeSeeAll = new Map();
    let activeProjName = null;

    virtualItems.forEach(el => {
      const projCard = el.querySelector('button[data-project-card="true"]');
      if (projCard) {
        activeProjName = (projCard.innerText || '').trim();
        if (!projectTasks.has(activeProjName)) {
          projectTasks.set(activeProjName, []);
        }
        return;
      }

      const sh = el.querySelector('[data-testid="section-header"]');
      if (sh) {
        activeProjName = null;
        return;
      }

      const row = el.querySelector('[data-testid="conversation-row-sidebar"]');
      if (row && activeProjName) {
        projectTasks.get(activeProjName).push(el);
        return;
      }

      const btn = el.querySelector('button');
      if (btn && /see all|see less/i.test(btn.innerText || '')) {
        el.setAttribute('data-gemini-native-see-all', 'true');
        el.style.display = 'none';
        if (activeProjName) {
          projectNativeSeeAll.set(activeProjName, btn);
        }
      }
    });

    // 2. Apply 3-item limit per project and manage synthetic project pagers
    projectTasks.forEach((tasks, projName) => {
      const loaded = parseInt(sessionStorage.getItem(PROJECT_LOADED_PREFIX + projName) || '0', 10) || 0;
      const maxVisible = PROJECT_PAGE_SIZE + loaded;
      const total = tasks.length;
      const nativeSeeAll = projectNativeSeeAll.get(projName);

      tasks.forEach((taskEl, taskIdx) => {
        if (taskIdx < maxVisible) {
          taskEl.style.display = '';
        } else {
          taskEl.style.display = 'none';
        }
      });

      let pager = inner.querySelector(`[${SYNTHETIC_PROJ_PAGER_ATTR}="${projName}"]`);
      if (total > PROJECT_PAGE_SIZE || nativeSeeAll) {
        if (!pager) {
          pager = document.createElement('div');
          pager.setAttribute(SYNTHETIC_PROJ_PAGER_ATTR, projName);
          inner.appendChild(pager);
        }
        pager.className = 'w-full flex flex-col gap-[1px] select-none';

        const hasMore = maxVisible < total;
        const hasLess = loaded > 0;

        const nextHtml = `
          <button type="button" data-gemini-plus-proj-action="more" style="display: ${hasMore ? 'flex' : 'none'};" class="relative w-full select-none cursor-pointer rounded-lg flex flex-row group pl-[30px] pr-2 py-1.5 items-center transition-colors text-xs text-muted-foreground hover:bg-sidebar-muted hover:text-foreground border-none bg-transparent font-medium focus:outline-none text-left">Show more</button>
          <button type="button" data-gemini-plus-proj-action="less" style="display: ${hasLess ? 'flex' : 'none'};" class="relative w-full select-none cursor-pointer rounded-lg flex flex-row group pl-[30px] pr-2 py-1.5 items-center transition-colors text-xs text-muted-foreground hover:bg-sidebar-muted hover:text-foreground border-none bg-transparent font-medium focus:outline-none text-left">Show less</button>
        `;

        if (pager.innerHTML !== nextHtml) {
          pager.innerHTML = nextHtml;
        }

        if (!pager.__hasListener) {
          pager.__hasListener = true;
          pager.addEventListener('click', (e) => {
            const more = e.target.closest('[data-gemini-plus-proj-action="more"]');
            if (more) {
              e.preventDefault();
              e.stopPropagation();
              const curr = parseInt(sessionStorage.getItem(PROJECT_LOADED_PREFIX + projName) || '0', 10) || 0;
              const nextLoaded = curr + PROJECT_PAGE_SIZE;
              sessionStorage.setItem(PROJECT_LOADED_PREFIX + projName, String(nextLoaded));
              const seeAll = projectNativeSeeAll.get(projName);
              if (seeAll && nextLoaded >= total) {
                try { seeAll.click(); } catch (err) {}
                setTimeout(() => applyEnhancements(), 50);
                setTimeout(() => applyEnhancements(), 200);
              }
              applyEnhancements();
              return;
            }
            const less = e.target.closest('[data-gemini-plus-proj-action="less"]');
            if (less) {
              e.preventDefault();
              e.stopPropagation();
              sessionStorage.setItem(PROJECT_LOADED_PREFIX + projName, '0');
              applyEnhancements();
              return;
            }
          });
        }
      } else if (pager) {
        pager.remove();
      }
    });

    // 3. Collect elements in sequential vertical order
    const layoutElements = [];

    virtualItems.forEach((el, idx) => {
      if (projectsHeaderIdx !== -1 && idx === projectsHeaderIdx) {
        if (section) layoutElements.push(section);
      }

      if (el.style.display !== 'none' && !el.getAttribute('data-gemini-native-see-all')) {
        layoutElements.push(el);

        // Check if this task is the last visible task of an active project
        const isProjCard = !!el.querySelector('button[data-project-card="true"]');
        if (!isProjCard) {
          projectTasks.forEach((tasks, projName) => {
            const visibleTasks = tasks.filter(t => t.style.display !== 'none');
            if (visibleTasks.length > 0 && visibleTasks[visibleTasks.length - 1] === el) {
              const pager = inner.querySelector(`[${SYNTHETIC_PROJ_PAGER_ATTR}="${projName}"]`);
              if (pager) layoutElements.push(pager);
            }
          });
        }
      }
    });

    if (projectsHeaderIdx === -1 && section) {
      layoutElements.unshift(section);
    }

    // 4. Position all elements sequentially without layout thrashing
    const heights = layoutElements.map(el => Math.round(el.getBoundingClientRect().height) || el.offsetHeight || 33);

    let currentY = 0;
    layoutElements.forEach((el, i) => {
      if (el.style.position !== 'absolute') el.style.position = 'absolute';
      if (el.style.top !== '0px') el.style.top = '0px';
      if (el.style.left !== '0px') el.style.left = '0px';
      if (el.style.width !== '100%') el.style.width = '100%';
      const transform = `translateY(${currentY}px)`;
      if (el.style.transform !== transform) el.style.transform = transform;
      if (el === section && el.style.zIndex !== '10') el.style.zIndex = '10';

      currentY += heights[i];
    });

    const nextHeight = `${currentY}px`;
    if (inner.style.height !== nextHeight) {
      inner.style.height = nextHeight;
    }
  }

  function renderRecentsSection(sidebarEl) {
    if (!sidebarEl) return;

    const inner = sidebarEl.firstElementChild || sidebarEl;

    let section = document.querySelector('[' + SYNTHETIC_SECTION_ATTR + ']');
    if (!section) {
      section = document.createElement('div');
      section.setAttribute(SYNTHETIC_SECTION_ATTR, 'recents');
      section.className = 'w-full bg-sidebar select-none';
      inner.appendChild(section);

      sidebarEl.addEventListener('scroll', () => {
        layoutSidebarVirtualizer(inner, section);
      }, { passive: true });
    } else if (section.parentElement !== inner) {
      inner.appendChild(section);
    }

    const allRecents = getRecents(sidebarEl);
    if (allRecents.length === 0) return;

    const currentPath = window.location.pathname || '';
    const isCollapsed = sessionStorage.getItem(RECENTS_KEY) === 'true';

    // Header
    let header = section.querySelector('.gemini-plus-recents-header');
    if (!header) {
      header = document.createElement('div');
      header.className = 'gemini-plus-recents-header group/section-header flex items-center justify-between py-1 px-2 select-none bg-sidebar cursor-pointer';
      header.innerHTML = `
        <h2 class="text-xs opacity-50 font-medium select-none m-0 min-w-0 flex items-center">
          <button type="button" aria-expanded="${!isCollapsed}" class="flex min-w-0 items-center gap-0.5 border-none bg-transparent p-0 text-left cursor-pointer font-inherit text-inherit rounded">
            <span class="truncate">Recents</span>
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 -960 960 960" fill="currentColor" class="recents-chevron shrink-0 transition-[opacity,transform] duration-150 ${isCollapsed ? '' : 'rotate-90'} opacity-0 group-hover/section-header:opacity-50 group-focus-within/section-header:opacity-50">
              <path d="M517.85-480l-184-184L376-706.15L602.15-480L376-253.85L333.85-296l184-184Z"></path>
            </svg>
          </button>
        </h2>
      `;

      header.addEventListener('click', () => {
        const nextCollapsed = sessionStorage.getItem(RECENTS_KEY) !== 'true';
        sessionStorage.setItem(RECENTS_KEY, String(nextCollapsed));
        const btn = header.querySelector('button');
        const chevron = header.querySelector('.recents-chevron');
        if (btn) btn.setAttribute('aria-expanded', String(!nextCollapsed));
        if (chevron) chevron.classList.toggle('rotate-90', !nextCollapsed);
        const list = section.querySelector('.gemini-plus-recents-list');
        if (list) list.style.display = nextCollapsed ? 'none' : 'flex';
        layoutSidebarVirtualizer(inner, section);
      });

      section.appendChild(header);
    }

    // List container
    let list = section.querySelector('.gemini-plus-recents-list');
    if (!list) {
      list = document.createElement('div');
      list.className = 'gemini-plus-recents-list flex flex-col gap-[1px] w-full';
      list.style.display = isCollapsed ? 'none' : 'flex';
      section.appendChild(list);
    }

    // Paging calculation
    let loaded = parseInt(sessionStorage.getItem(RECENTS_LOADED_KEY) || '0', 10);
    if (isNaN(loaded) || loaded < 0) loaded = 0;
    const totalCount = allRecents.length;
    const visibleCount = Math.min(totalCount, RECENTS_MIN_VISIBLE + loaded);
    const visibleRecents = allRecents.slice(0, visibleCount);

    const workingSet = getWorkingThreads();
    const unreadSet = getUnreadThreads();

    // Rows: single line with title (project) on left and timestamp / status on right (matching real thread styling)
    const rowsHtml = visibleRecents.map(t => {
      const isActive = currentPath.includes(t.cascadeId);
      const activeClasses = isActive ? 'bg-sidebar-secondary text-foreground' : 'text-secondary-foreground hover:bg-sidebar-muted hover:text-foreground';
      const displayTitle = t.projectName ? `${t.title} (${t.projectName})` : t.title;

      const isWorking = workingSet.has(t.cascadeId);
      const isUnread = !isWorking && unreadSet.has(t.cascadeId);
      const indicatorHtml = isWorking ? getSpinnerHtml() : (isUnread ? getUnreadDotHtml() : '');

      return `
        <div ${SYNTHETIC_ROW_ATTR}="true" data-cascade-id="${t.cascadeId}" role="button" tabindex="0" class="relative w-full select-none cursor-pointer rounded-lg flex flex-row justify-between group pl-[30px] pr-2 py-1.5 items-center transition-colors ${activeClasses}">
          <div class="relative flex gap-2 grow min-w-0 items-center pointer-events-none">
            <div class="flex flex-col items-start min-w-0 transition-opacity w-full">
              <span class="truncate inline-block truncate text-left w-full text-sm" title="${displayTitle.replace(/"/g, '&quot;')}">${displayTitle}</span>
            </div>
          </div>
          <div class="flex items-center gap-1 shrink-0 select-none pointer-events-none">
            <span class="text-xs text-muted-foreground opacity-60">${t.relativeTime}</span>
            ${indicatorHtml}
          </div>
        </div>
      `;
    }).join('');

    // Pager HTML (Show more / Show less)
    const hasMore = visibleCount < totalCount;
    const hasLess = loaded > 0;
    const showPager = totalCount > RECENTS_MIN_VISIBLE;

    const pagerHtml = showPager ? `
      <div data-gemini-plus-sidebar-pager="recents" class="w-full flex flex-col gap-[1px] select-none">
        <button type="button" data-gemini-plus-action="more" style="display: ${hasMore ? 'flex' : 'none'};" class="relative w-full select-none cursor-pointer rounded-lg flex flex-row group pl-[30px] pr-2 py-1.5 items-center transition-colors text-xs text-muted-foreground hover:bg-sidebar-muted hover:text-foreground border-none bg-transparent font-medium focus:outline-none text-left">Show more</button>
        <button type="button" data-gemini-plus-action="less" style="display: ${hasLess ? 'flex' : 'none'};" class="relative w-full select-none cursor-pointer rounded-lg flex flex-row group pl-[30px] pr-2 py-1.5 items-center transition-colors text-xs text-muted-foreground hover:bg-sidebar-muted hover:text-foreground border-none bg-transparent font-medium focus:outline-none text-left">Show less</button>
      </div>
    ` : '';

    const nextFullHtml = rowsHtml + pagerHtml;
    if (list.innerHTML !== nextFullHtml) {
      list.innerHTML = nextFullHtml;

      // Attach row navigation listeners
      list.querySelectorAll('[' + SYNTHETIC_ROW_ATTR + ']').forEach(row => {
        const navigate = () => {
          const cascadeId = row.getAttribute('data-cascade-id');
          if (cascadeId) {
            if (window.__TSR_ROUTER__ && window.__TSR_ROUTER__.history) {
              window.__TSR_ROUTER__.history.push('/c/' + cascadeId);
            } else {
              window.location.assign('/c/' + cascadeId);
            }
          }
        };

        row.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          navigate();
        });

        row.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            navigate();
          }
        });

        row.addEventListener('auxclick', (e) => {
          if (e.button === 1) {
            e.preventDefault();
            e.stopPropagation();
            const cascadeId = row.getAttribute('data-cascade-id');
            if (cascadeId) window.open('/c/' + cascadeId, '_blank');
          }
        });
      });

      // Attach pager button listeners
      const showMoreBtn = list.querySelector('[data-gemini-plus-action="more"]');
      if (showMoreBtn) {
        showMoreBtn.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          const currentLoaded = parseInt(sessionStorage.getItem(RECENTS_LOADED_KEY) || '0', 10) || 0;
          const nextLoaded = Math.min(totalCount - RECENTS_MIN_VISIBLE, currentLoaded + RECENTS_PAGE_SIZE);
          sessionStorage.setItem(RECENTS_LOADED_KEY, String(nextLoaded));
          applyEnhancements();
        });
      }

      const showLessBtn = list.querySelector('[data-gemini-plus-action="less"]');
      if (showLessBtn) {
        showLessBtn.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          sessionStorage.setItem(RECENTS_LOADED_KEY, '0');
          applyEnhancements();
        });
      }
    }

    // Apply layout shift after render/update
    layoutSidebarVirtualizer(inner, section);
  }

  let applying = false;
  function applyEnhancements() {
    if (window.__GEMINI_PLUS_SIDEBAR_INSTANCE !== INSTANCE_ID) return;
    if (applying) return;
    applying = true;
    try {
      syncActiveTaskStatus();
      applyTerminology(document.body);
      const sidebarEl = document.querySelector('[data-testid="conversation-list-sidebar"]');
      if (sidebarEl) {
        renderRecentsSection(sidebarEl);
        syncNativeRowIndicators();
      }
      restoreOpenStates();
    } finally {
      applying = false;
    }
  }

  let scheduleTimer = null;
  function scheduleApply() {
    if (scheduleTimer) return;
    scheduleTimer = requestAnimationFrame(() => {
      scheduleTimer = null;
      applyEnhancements();
    });
  }

  const observer = new MutationObserver((mutations) => {
    if (window.__GEMINI_PLUS_SIDEBAR_INSTANCE !== INSTANCE_ID) {
      observer.disconnect();
      return;
    }
    if (applying) return;
    const hasMeaningfulChange = mutations.some(m => {
      if (m.target instanceof Element && (
        m.target.closest('[' + SYNTHETIC_SECTION_ATTR + ']') ||
        m.target.closest('[' + SYNTHETIC_PROJ_PAGER_ATTR + ']') ||
        m.target.closest('[data-gemini-plus-thread-spinner]') ||
        m.target.closest('[data-gemini-plus-thread-unread]')
      )) return false;
      return true;
    });
    if (hasMeaningfulChange) scheduleApply();
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['aria-expanded', 'aria-label', 'title', 'data-title', 'data-testid', 'style']
  });

  window.__GEMINI_PLUS_SIDEBAR_ENHANCEMENTS = {
    apply: applyEnhancements,
    observer
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyEnhancements, { once: true });
  } else {
    applyEnhancements();
  }

  setInterval(() => {
    if (window.__GEMINI_PLUS_SIDEBAR_INSTANCE !== INSTANCE_ID) return;
    applyEnhancements();
  }, 2000);
})();
'@
}
