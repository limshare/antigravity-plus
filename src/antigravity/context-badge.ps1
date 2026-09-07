function Get-AntigravityContextBadgePayload {
    @'
(function () {
  const BADGE_ID = 'data-gemini-plus-top-badge';

  if (window.__GEMINI_PLUS_CONTEXT_BADGE && window.__GEMINI_PLUS_CONTEXT_BADGE.observer) {
    try { window.__GEMINI_PLUS_CONTEXT_BADGE.observer.disconnect(); } catch (e) {}
  }
  if (window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE && window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE.observer) {
    try { window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE.observer.disconnect(); } catch (e) {}
  }

  // Cleanup any legacy badges
  try {
    document.querySelectorAll('[data-antigravity-plus-context-badge]').forEach(function (el) { el.remove(); });
  } catch (e) {}

  const INSTANCE_ID = (window.__GEMINI_PLUS_BADGE_INSTANCE = (window.__GEMINI_PLUS_BADGE_INSTANCE || 0) + 1);
  const BADGE_RELEVANT_SELECTOR = '[data-testid="title-menu-bar"], [data-testid="model-selector-trigger"], [aria-label*="Context" i]';
  let statusText = '';
  let cachedUserStatus = null;
  let cachedQuotaSummary = null;
  let cachedQuotaText = '';
  try {
    cachedQuotaText = localStorage.getItem('gemini_plus_cached_quota') || localStorage.getItem('antigravity_plus_cached_quota') || '';
    const rawSummary = localStorage.getItem('gemini_plus_quota_summary');
    if (rawSummary) cachedQuotaSummary = JSON.parse(rawSummary);
    const rawStatus = localStorage.getItem('gemini_plus_user_status');
    if (rawStatus) cachedUserStatus = JSON.parse(rawStatus);
  } catch (e) {}
  let isFetchingStatus = false;
  let lastFetchTime = 0;

  function normalizeText(text) {
    return String(text || '').replace(/\s+/g, ' ').trim();
  }

  function stripBidiMarks(text) {
    return String(text || '').replace(/[\u0591-\u05C7\u200E\u200F\u202A-\u202E]/g, '');
  }

  function formatResetTime(resetTime) {
    if (!resetTime) return '';
    const resetDate = new Date(resetTime);
    const now = new Date();
    const diffMs = resetDate.getTime() - now.getTime();
    if (diffMs <= 0) return 'resets now';
    const diffHours = Math.ceil(diffMs / (1000 * 60 * 60));
    const diffMins = Math.ceil(diffMs / (1000 * 60));
    const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));
    if (diffDays >= 1 && diffHours > 24) {
      return 'resets in ' + diffDays + (diffDays === 1 ? ' day' : ' days');
    } else if (diffHours >= 1) {
      return 'resets in ' + diffHours + (diffHours === 1 ? ' hour' : ' hours');
    } else {
      return 'resets in ' + diffMins + (diffMins === 1 ? ' minute' : ' minutes');
    }
  }

  function formatBucketDetail(bucket) {
    if (!bucket) return '';
    const usedFraction = 1 - (bucket.remainingFraction != null ? Number(bucket.remainingFraction) : 1);
    const usedPercent = Math.max(0, Math.min(100, Math.round(usedFraction * 100)));
    const resetStr = formatResetTime(bucket.resetTime);
    if (resetStr) {
      return usedPercent + '% used \u00B7 ' + resetStr;
    }
    return usedPercent + '% used';
  }

  async function fetchGeminiUserStatus() {
    if (window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) return;
    if (isFetchingStatus) return;
    const now = Date.now();
    if (cachedUserStatus && cachedQuotaSummary && now - lastFetchTime < 30000) return;
    isFetchingStatus = true;
    try {
      const csrfToken = window.__APP_CONFIG__?.csrfToken;
      const headers = {
        'content-type': 'application/json',
        ...(csrfToken ? { 'x-codeium-csrf-token': csrfToken } : {})
      };

      const [summaryRes, statusRes] = await Promise.allSettled([
        fetch('/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary', {
          method: 'POST',
          headers,
          body: '{}'
        }),
        fetch('/exa.language_server_pb.LanguageServerService/GetUserStatus', {
          method: 'POST',
          headers,
          body: '{}'
        })
      ]);

      let updated = false;
      if (summaryRes.status === 'fulfilled' && summaryRes.value && summaryRes.value.ok) {
        try {
          const summaryData = await summaryRes.value.json();
          cachedQuotaSummary = summaryData.response || summaryData;
          localStorage.setItem('gemini_plus_quota_summary', JSON.stringify(cachedQuotaSummary));
          updated = true;
        } catch (e) {}
      }

      if (statusRes.status === 'fulfilled' && statusRes.value && statusRes.value.ok) {
        try {
          const statusData = await statusRes.value.json();
          cachedUserStatus = statusData.userStatus || statusData;
          localStorage.setItem('gemini_plus_user_status', JSON.stringify(cachedUserStatus));
          updated = true;
        } catch (e) {}
      }

      if (updated && window.__GEMINI_PLUS_BADGE_INSTANCE === INSTANCE_ID) {
        lastFetchTime = Date.now();
        apply();
      }
    } catch (e) {
    } finally {
      isFetchingStatus = false;
    }
  }

  function getGeminiQuotaText(scopeDoc) {
    const modelSelector = scopeDoc?.querySelector('[data-testid="model-selector-trigger"]') || document.querySelector('[data-testid="model-selector-trigger"]');
    const rawActiveText = normalizeText(modelSelector?.innerText || modelSelector?.getAttribute('aria-label') || '');
    const cleanActiveText = rawActiveText.toLowerCase().replace(/[^a-z0-9]/g, '');

    let cleanModelLabel = rawActiveText.replace(/\s*\((Medium|High|Low|Thinking)\)/i, '').replace(/\s+(Medium|High|Low|Thinking)$/i, '').trim();

    const configs = cachedUserStatus?.cascadeModelConfigData?.clientModelConfigs || [];
    if (!cleanModelLabel && configs.length > 0) {
      const defaultModel = configs.find(function (m) { return (m.label || '').toLowerCase().includes('gemini'); }) || configs[0];
      cleanModelLabel = (defaultModel.label || 'Gemini').replace(/\s*\((Medium|High|Low|Thinking)\)/i, '').replace(/\s+(Medium|High|Low|Thinking)$/i, '').trim();
    }
    if (!cleanModelLabel) {
      cleanModelLabel = 'Gemini';
    }

    const groups = cachedQuotaSummary?.groups || [];
    let quotaDetails = [];

    if (groups.length > 0) {
      let matchedGroup = null;
      if (cleanActiveText.includes('claude') || cleanActiveText.includes('gpt') || cleanActiveText.includes('3p') || cleanActiveText.includes('sonnet') || cleanActiveText.includes('opus')) {
        matchedGroup = groups.find(function (g) {
          return /claude|gpt|3p|sonnet|opus/i.test((g.displayName || '') + ' ' + (g.description || ''));
        });
      } else {
        matchedGroup = groups.find(function (g) {
          return /gemini/i.test((g.displayName || '') + ' ' + (g.description || ''));
        });
      }
      if (!matchedGroup) matchedGroup = groups[0];

      if (matchedGroup?.buckets?.length) {
        const fiveHourBucket = matchedGroup.buckets.find(function (b) {
          return b.window === '5h' || (b.bucketId || '').includes('5h') || /five/i.test(b.displayName || '');
        });
        const weeklyBucket = matchedGroup.buckets.find(function (b) {
          return b.window === 'weekly' || (b.bucketId || '').includes('weekly') || /weekly/i.test(b.displayName || '');
        });

        if (fiveHourBucket && weeklyBucket) {
          quotaDetails.push('5h: ' + formatBucketDetail(fiveHourBucket));
          quotaDetails.push('Weekly: ' + formatBucketDetail(weeklyBucket));
        } else if (fiveHourBucket) {
          quotaDetails.push(formatBucketDetail(fiveHourBucket));
        } else if (weeklyBucket) {
          quotaDetails.push(formatBucketDetail(weeklyBucket));
        }
      }
    }

    if (quotaDetails.length === 0 && configs.length > 0) {
      let matchedModel = configs.find(function (m) {
        return (m.label || '').toLowerCase().replace(/[^a-z0-9]/g, '') === cleanActiveText;
      });
      if (!matchedModel && cleanActiveText) {
        matchedModel = configs.find(function (m) {
          const cleanLabel = (m.label || '').toLowerCase().replace(/[^a-z0-9]/g, '');
          return cleanActiveText.includes(cleanLabel) || cleanLabel.includes(cleanActiveText);
        });
      }
      if (!matchedModel) {
        matchedModel = configs.find(function (m) {
          return (m.label || '').toLowerCase().includes('gemini');
        }) || configs[0];
      }
      if (matchedModel?.quotaInfo) {
        quotaDetails.push(formatBucketDetail(matchedModel.quotaInfo));
      }
    }

    if (quotaDetails.length > 0) {
      const text = cleanModelLabel + ' - ' + quotaDetails.join(' | ');
      cachedQuotaText = text;
      try {
        localStorage.setItem('gemini_plus_cached_quota', text);
        localStorage.setItem('antigravity_plus_cached_quota', text);
      } catch (e) {}
      return text;
    }

    if ((!cachedUserStatus || !cachedQuotaSummary) && !isFetchingStatus) {
      fetchGeminiUserStatus();
    }
    return cachedQuotaText;
  }

  function ensureBadge(scopeDoc) {
    if (!scopeDoc) return;

    try {
      scopeDoc.querySelectorAll('[data-antigravity-plus-context-badge]').forEach(function (el) {
        try { el.remove(); } catch (e) {}
      });
    } catch (e) {}

    let badge = scopeDoc.querySelector('[' + BADGE_ID + ']');
    if (!badge) {
      badge = scopeDoc.createElement('div');
      badge.setAttribute(BADGE_ID, 'true');
      badge.setAttribute('aria-hidden', 'true');
      badge.style.position = 'fixed';
      badge.style.insetInlineStart = '50%';
      badge.style.top = '8px';
      badge.style.transform = 'translateX(-50%)';
      badge.style.zIndex = '2147483647';
      badge.style.pointerEvents = 'none';
      badge.style.userSelect = 'none';
      badge.style.padding = '0';
      badge.style.margin = '0';
      badge.style.border = '0';
      badge.style.background = 'transparent';
      badge.style.boxShadow = 'none';
      badge.style.backdropFilter = 'none';
      badge.style.webkitBackdropFilter = 'none';
      badge.style.whiteSpace = 'nowrap';
      badge.style.display = 'inline-flex';
      badge.style.width = 'max-content';
      badge.style.maxWidth = 'calc(100vw - 240px)';
      badge.style.overflow = 'visible';
      badge.style.font = '600 13px/1.2 system-ui, -apple-system, sans-serif';
      badge.style.color = '#9ca3af';
    }

    const menuBar = scopeDoc.querySelector('[data-testid="title-menu-bar"]');
    const header = menuBar || scopeDoc.querySelector('header') || scopeDoc.body || scopeDoc.documentElement || scopeDoc;
    if (badge.parentElement !== header) {
      if (badge.parentElement) badge.parentElement.removeChild(badge);
      if (header && header.style && getComputedStyle(header).position === 'static') {
        header.style.position = 'relative';
      }
      header.appendChild(badge);
    }

    const quotaInfo = getGeminiQuotaText(scopeDoc);
    const nextText = stripBidiMarks(['Plus', quotaInfo || statusText].filter(Boolean).join(' '));
    if (badge.textContent !== nextText) {
      badge.textContent = nextText;
    }
  }

  let pending = false;
  let observing = false;
  let applying = false;

  const schedule = () => {
    if (window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) {
      disconnect();
      return;
    }
    if (pending || applying) return;
    pending = true;
    window.setTimeout(() => {
      pending = false;
      apply();
    }, 100);
  };

  function mutationTouchesBadgeSource(record) {
    const target = record.target instanceof Element
      ? record.target
      : record.target?.parentElement;
    if (!target) return false;
    if (target.hasAttribute(BADGE_ID) || target.closest('[' + BADGE_ID + ']') ||
        target.hasAttribute('data-antigravity-plus-context-badge') || target.closest('[data-antigravity-plus-context-badge]')) {
      return false;
    }
    if (target.matches(BADGE_RELEVANT_SELECTOR) || target.closest(BADGE_RELEVANT_SELECTOR)) return true;
    return Array.from(record.addedNodes || []).some(function (node) {
      return node instanceof Element && (
        node.matches(BADGE_RELEVANT_SELECTOR) || Boolean(node.querySelector(BADGE_RELEVANT_SELECTOR))
      );
    });
  }

  const observer = new MutationObserver((records) => {
    if (window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) {
      disconnect();
      return;
    }
    if (records.some(mutationTouchesBadgeSource)) schedule();
  });

  const observe = () => {
    if (observing || !document.documentElement || window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) return;
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['aria-label', 'title', 'data-testid'],
      childList: true,
      subtree: true
    });
    observing = true;
  };

  const disconnect = () => {
    if (!observing) return;
    try { observer.disconnect(); } catch(e) {}
    observing = false;
  };

  const apply = () => {
    if (window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) {
      disconnect();
      return;
    }
    if (applying) return;
    const wasObserving = observing;
    if (wasObserving) disconnect();
    applying = true;
    try {
      ensureBadge(document);
    } finally {
      applying = false;
      if (wasObserving && window.__GEMINI_PLUS_BADGE_INSTANCE === INSTANCE_ID) {
        observe();
      }
    }
  };

  const start = () => {
    disconnect();
    fetchGeminiUserStatus();
    apply();
    observe();
  };

  window.__GEMINI_PLUS_CONTEXT_BADGE = {
    apply,
    observer,
    setStatus(nextStatus) {
      statusText = normalizeText(nextStatus);
      apply();
    },
    clearStatus() {
      statusText = '';
      apply();
    },
    refresh() {
      fetchGeminiUserStatus();
    }
  };
  window.__ANTIGRAVITY_PLUS_CONTEXT_BADGE = window.__GEMINI_PLUS_CONTEXT_BADGE;

  window.addEventListener('antigravity-plus-usage-updated', () => window.__GEMINI_PLUS_CONTEXT_BADGE.refresh());
  window.addEventListener('gemini-plus-usage-updated', () => window.__GEMINI_PLUS_CONTEXT_BADGE.refresh());

  // Periodic background refresh every 30s
  const refreshInterval = window.setInterval(() => {
    if (window.__GEMINI_PLUS_BADGE_INSTANCE !== INSTANCE_ID) {
      window.clearInterval(refreshInterval);
      return;
    }
    fetchGeminiUserStatus();
  }, 30000);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
'@
}
