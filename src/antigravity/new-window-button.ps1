function Get-AntigravityNewWindowButtonPayload {
    @'
(function () {
  const HEADER_SELECTOR = '[data-testid="title-menu-bar"], .app-header-tint';
  const MENU_GROUP_SELECTOR = '[data-testid="title-menu-bar"], [role="menubar"][aria-label="Application menu"], [role="menubar"]';
  const BUTTON_ATTR = 'data-antigravity-plus-shared-window-button';
  const LEGACY_BUTTON_ATTR = 'data-gemini-plus-shared-window-button';
  const PROJECT_BUTTON_ATTR = 'data-antigravity-plus-project-window-button';
  const LEGACY_PROJECT_BUTTON_ATTR = 'data-gemini-plus-project-window-button';
  const PENDING_PROJECT_WINDOWS_KEY = 'antigravityPlusPendingProjectWindows';
  const LAUNCH_REQUEST_KEY = 'antigravity_plus_new_window_request';
  const BUILD_VERSION = '2026.09.18.3';
  const INSTANCE_ID = (window.__ANTIGRAVITY_PLUS_NEW_WINDOW_BUTTON_INSTANCE = (window.__ANTIGRAVITY_PLUS_NEW_WINDOW_BUTTON_INSTANCE || 0) + 1);

  function consumePendingProjectWindow() {
    try {
      const raw = localStorage.getItem(PENDING_PROJECT_WINDOWS_KEY);
      if (!raw) return;
      const pending = JSON.parse(raw);
      if (!Array.isArray(pending) || pending.length === 0) return;

      const now = Date.now();
      const valid = pending.filter((p) => now - (p.createdAt || 0) < 60000);
      if (valid.length === 0) {
        localStorage.removeItem(PENDING_PROJECT_WINDOWS_KEY);
        return;
      }

      const item = valid.pop();
      localStorage.setItem(PENDING_PROJECT_WINDOWS_KEY, JSON.stringify(valid));

      if (item && item.antigravityPlusProjectName) {
        sessionStorage.setItem('antigravity_plus_last_project', item.antigravityPlusProjectName);
        localStorage.setItem('antigravity_plus_last_project', item.antigravityPlusProjectName);
        window.__ANTIGRAVITY_PLUS_PROJECT_WINDOW_CONTEXT = {
          id: item.antigravityPlusProjectId || '',
          name: item.antigravityPlusProjectName
        };
        if (item.startupPath && item.startupPath !== '/' && (location.pathname === '/' || location.pathname === '')) {
          history.replaceState(null, '', item.startupPath);
        }
      }
    } catch (e) {}
  }

  // Consume any project navigation queued for this fresh window
  consumePendingProjectWindow();

  function hasInstalledButtons() {
    const existing = document.querySelector('[' + BUTTON_ATTR + ']');
    return Boolean(existing && existing.getAttribute('data-antigravity-plus-version') === BUILD_VERSION);
  }

  if (window.__ANTIGRAVITY_PLUS_NEW_WINDOW_BUTTON && hasInstalledButtons()) return;

  function getMenuGroup() {
    return document.querySelector('[data-testid="title-menu-bar"]')
      || document.querySelector(HEADER_SELECTOR + ' ' + MENU_GROUP_SELECTOR)
      || document.querySelector(MENU_GROUP_SELECTOR)
      || document.querySelector('button[aria-label="Help"]')?.parentElement
      || null;
  }

  function projectContextFromRow(row) {
    if (!row) return null;
    const id = row.getAttribute('data-app-action-sidebar-project-id')
      || row.getAttribute('data-project-id')
      || row.closest('[data-project-id]')?.getAttribute('data-project-id')
      || row.querySelector('[data-app-action-sidebar-project-id]')?.getAttribute('data-app-action-sidebar-project-id');
    const name = row.getAttribute('data-app-action-sidebar-project-label')
      || row.getAttribute('data-project-label')
      || row.querySelector('[data-app-action-sidebar-project-label]')?.textContent
      || row.innerText
      || row.textContent;
    return id && name ? { id: String(id).trim(), name: String(name).replace(/\s+/g, ' ').trim() } : (name ? { id: '', name: String(name).replace(/\s+/g, ' ').trim() } : null);
  }

  function currentProjectContext() {
    if (window.__ANTIGRAVITY_PLUS_PROJECT_WINDOW_CONTEXT?.id && window.__ANTIGRAVITY_PLUS_PROJECT_WINDOW_CONTEXT?.name) {
      return window.__ANTIGRAVITY_PLUS_PROJECT_WINDOW_CONTEXT;
    }
    if (window.__GEMINI_PLUS_PROJECT_WINDOW_CONTEXT?.id && window.__GEMINI_PLUS_PROJECT_WINDOW_CONTEXT?.name) {
      return window.__GEMINI_PLUS_PROJECT_WINDOW_CONTEXT;
    }

    const active = document.querySelector('[data-app-action-sidebar-thread-active="true"], [data-testid="conversation-row-sidebar"].bg-sidebar-secondary');
    const projectRow = active?.closest('[data-app-action-sidebar-project-row]')
      || active?.closest('[data-project-card="true"]');
    const rowContext = projectContextFromRow(projectRow);
    if (rowContext) return rowContext;

    try {
      const lastProj = sessionStorage.getItem('antigravity_plus_last_project') || localStorage.getItem('antigravity_plus_last_project');
      if (lastProj && lastProj !== 'Workspace') {
        return { id: '', name: lastProj };
      }
    } catch (e) {}

    return null;
  }

  function getProjectStartupPath(context) {
    if (context?.id) {
      return '/?section=' + encodeURIComponent(context.id);
    }
    return '/';
  }

  function launchSharedWindow(context) {
    const projectName = context?.name ? String(context.name).replace(/\s+/g, ' ').trim() : '';
    const statusMsg = '- Launching ' + (projectName ? projectName + ' ' : '') + 'window';

    if (window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE?.setStatus) {
      window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE.setStatus(statusMsg);
    } else if (window.__GEMINI_PLUS_CONTEXT_BADGE?.setStatus) {
      window.__GEMINI_PLUS_CONTEXT_BADGE.setStatus(statusMsg);
    }

    const path = context?.name ? getProjectStartupPath(context) : '/';
    if (context?.name) {
      try {
        const pending = JSON.parse(localStorage.getItem(PENDING_PROJECT_WINDOWS_KEY) || '[]');
        pending.push({
          antigravityPlusProjectId: context.id || '',
          antigravityPlusProjectName: context.name,
          startupPath: path,
          createdAt: Date.now()
        });
        localStorage.setItem(PENDING_PROJECT_WINDOWS_KEY, JSON.stringify(pending.slice(-20)));
      } catch (e) {}
    }

    const launchRequest = {
      id: 'req-' + Date.now() + '-' + Math.random().toString(36).substring(2, 7),
      timestamp: Date.now(),
      context: context || null,
      path: path || '/'
    };

    try {
      localStorage.setItem(LAUNCH_REQUEST_KEY, JSON.stringify(launchRequest));
    } catch (e) {}

    // Event-driven direct request to local monitor control listener (Option 2)
    const controlPort = window.__ANTIGRAVITY_PLUS_CONTROL_PORT;
    if (controlPort) {
      try {
        fetch('http://127.0.0.1:' + controlPort + '/new-window/', {
          method: 'POST',
          mode: 'no-cors'
        }).catch(() => {});
      } catch (e) {}
    }

    try {
      if (window.nativeStorage?.updateItems) {
        window.nativeStorage.updateItems({ [LAUNCH_REQUEST_KEY]: JSON.stringify(launchRequest) });
      }
    } catch (e) {}

    try {
      const bridge = window.electronBridge?.sendMessageFromView;
      if (typeof bridge === 'function') {
        const launchRequestPromise = Promise.resolve(bridge({ type: 'open-in-new-window', path }));
        launchRequestPromise.catch(() => {
          window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE?.clearStatus();
          window.__GEMINI_PLUS_CONTEXT_BADGE?.clearStatus();
        });
      }
    } catch (e) {}

    window.dispatchEvent(new CustomEvent('antigravity-plus-new-window', { detail: { context, path } }));
    window.dispatchEvent(new CustomEvent('gemini-plus-new-window', { detail: { context, path } }));

    window.setTimeout(() => {
      window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE?.clearStatus();
      window.__GEMINI_PLUS_CONTEXT_BADGE?.clearStatus();
    }, 5000);
  }

  function installProjectButtons() {
    const projectRows = document.querySelectorAll('[data-app-action-sidebar-project-row]');
    for (const row of projectRows) {
      const existing = row.querySelector('[' + PROJECT_BUTTON_ATTR + ']');
      if (existing) {
        if (existing.getAttribute('data-antigravity-plus-version') === BUILD_VERSION) continue;
        existing.remove();
      }
      const context = projectContextFromRow(row);
      if (!context) continue;
      const button = document.createElement('button');
      button.type = 'button';
      button.setAttribute(PROJECT_BUTTON_ATTR, 'true');
      button.setAttribute(LEGACY_PROJECT_BUTTON_ATTR, 'true');
      button.setAttribute('data-antigravity-plus-version', BUILD_VERSION);
      button.setAttribute('aria-label', 'New window');
      button.title = 'Open project in a new window';
      button.className = 'no-drag rounded-md border border-transparent px-2 py-1 text-muted-foreground hover:bg-secondary hover:text-foreground text-xs select-none transition-colors';
      button.style.cssText = '-webkit-app-region: no-drag !important; app-region: no-drag !important; pointer-events: auto !important; cursor: pointer !important;';
      button.textContent = '> New window';
      button.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
        launchSharedWindow(projectContextFromRow(row));
      });
      (row.querySelector('[data-app-action-sidebar-project-label]')?.parentElement || row).appendChild(button);
    }
  }

  function install() {
    installProjectButtons();
    if (!window.__ANTIGRAVITY_PLUS_NEW_WINDOW_GLOBAL_GUARD) {
      function handleGlobalWindowClick(event) {
        const menubarTarget = event.target instanceof Element
          ? event.target.closest('[' + BUTTON_ATTR + '], [' + LEGACY_BUTTON_ATTR + '], [data-testid="title-menu-bar-new-window-btn"]')
          : null;
        if (menubarTarget) {
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
          if (menubarTarget.disabled) return;
          menubarTarget.disabled = true;
          try {
            launchSharedWindow(null);
          } finally {
            window.setTimeout(() => { menubarTarget.disabled = false; }, 1200);
          }
          return;
        }

        const projectTarget = event.target instanceof Element
          ? event.target.closest('[' + PROJECT_BUTTON_ATTR + '], [' + LEGACY_PROJECT_BUTTON_ATTR + ']')
          : null;
        if (projectTarget) {
          const row = projectTarget.closest('[data-app-action-sidebar-project-row], button[data-project-card="true"]');
          const context = projectContextFromRow(row);
          if (!context) return;
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
          if (projectTarget.disabled) return;
          projectTarget.disabled = true;
          try {
            launchSharedWindow(context);
          } finally {
            window.setTimeout(() => { projectTarget.disabled = false; }, 1200);
          }
          return;
        }
      }

      document.addEventListener('click', handleGlobalWindowClick, true);
      document.addEventListener('pointerup', handleGlobalWindowClick, true);
      window.__ANTIGRAVITY_PLUS_NEW_WINDOW_GLOBAL_GUARD = true;
    }

    const menuGroup = getMenuGroup();
    if (menuGroup) {
      let existingButton = menuGroup.querySelector('[' + BUTTON_ATTR + ']');
      if (existingButton && existingButton.getAttribute('data-antigravity-plus-version') !== BUILD_VERSION) {
        const wrapper = existingButton.closest('[data-antigravity-plus-new-window-wrapper]');
        if (wrapper) wrapper.remove();
        else existingButton.remove();
        existingButton = null;
      }

      if (!existingButton) {
        const nativeButton = menuGroup.querySelector('button');
        const button = document.createElement('button');
        button.type = 'button';
        button.setAttribute(BUTTON_ATTR, 'true');
        button.setAttribute(LEGACY_BUTTON_ATTR, 'true');
        button.setAttribute('data-antigravity-plus-version', BUILD_VERSION);
        button.setAttribute('data-testid', 'title-menu-bar-new-window-btn');
        button.setAttribute('aria-label', 'New window (Ctrl+Shift+N)');
        button.title = 'Open a new Antigravity window in this Plus session (Ctrl+Shift+N)';
        button.className = nativeButton?.className || 'inline-flex items-center font-medium transition-colors select-none outline-none cursor-pointer justify-center disabled:opacity-50 bg-transparent text-muted-foreground hover:text-foreground hover:bg-secondary focus-visible:text-foreground focus-visible:bg-secondary h-7 text-sm rounded-md gap-1.5 px-2.5 select-none';
        button.style.cssText = '-webkit-app-region: no-drag !important; app-region: no-drag !important; pointer-events: auto !important; cursor: pointer !important; position: relative; z-index: 100;';
        button.innerHTML = '<span aria-hidden="true" style="font-size:16px;line-height:1;pointer-events:none;-webkit-app-region:no-drag;">></span><span style="pointer-events:none;-webkit-app-region:no-drag;">New window</span>';
        button.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          if (button.disabled) return;
          button.disabled = true;
          try { launchSharedWindow(null); }
          finally { window.setTimeout(() => { button.disabled = false; }, 1200); }
        });

        // If items in menuGroup are wrapped in <div class="relative" style="app-region: no-drag;">, wrap accordingly
        if (menuGroup.getAttribute('data-testid') === 'title-menu-bar' && nativeButton?.parentElement && nativeButton.parentElement !== menuGroup) {
          const wrapper = document.createElement('div');
          wrapper.className = nativeButton.parentElement.className || 'relative';
          wrapper.style.cssText = '-webkit-app-region: no-drag !important; app-region: no-drag !important; pointer-events: auto !important;';
          wrapper.setAttribute('data-antigravity-plus-new-window-wrapper', 'true');
          wrapper.appendChild(button);
          menuGroup.appendChild(wrapper);
        } else {
          menuGroup.appendChild(button);
        }
      }
    }
  }

  let installPending = false;
  const INSTALL_SURFACE_SELECTOR = [
    HEADER_SELECTOR,
    MENU_GROUP_SELECTOR,
    '[data-app-action-sidebar-project-row]',
    '[data-testid="title-menu-bar"]'
  ].join(',');

  function mutationTouchesInstallSurface(record) {
    const target = record.target instanceof Element
      ? record.target
      : record.target?.parentElement;
    if (target?.matches(INSTALL_SURFACE_SELECTOR) || target?.closest(INSTALL_SURFACE_SELECTOR)) return true;
    return [...Array.from(record.addedNodes || []), ...Array.from(record.removedNodes || [])].some((node) => {
      return node instanceof Element && (
        node.matches(INSTALL_SURFACE_SELECTOR) || Boolean(node.querySelector(INSTALL_SURFACE_SELECTOR))
      );
    });
  }

  function scheduleInstall(records) {
    if (records && !records.some(mutationTouchesInstallSurface)) return;
    if (installPending) return;
    installPending = true;
    window.setTimeout(() => {
      installPending = false;
      install();
    }, 80);
  }

  install();
  window.__ANTIGRAVITY_PLUS_NEW_WINDOW_BUTTON = true;
  window.__GEMINI_PLUS_NEW_WINDOW_BUTTON = true;
  new MutationObserver(scheduleInstall).observe(document.documentElement, { childList: true, subtree: true });
  window.setInterval(scheduleInstall, 5000);
})();
'@
}
