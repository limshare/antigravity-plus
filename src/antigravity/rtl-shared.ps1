function Get-AntigravityRtlSharedHelpers {
    @'
(function () {
  if (window.__AGY_RTL_SHARED) {
    return window.__AGY_RTL_SHARED;
  }

  const RTL_RE = /[\u0590-\u05FF\uFB1D-\uFB4F\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/;
  const LTR_RE = /[A-Za-z\u00C0-\u024F]/;
  const STRONG_RE = /[\u0590-\u05FF\uFB1D-\uFB4F\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]|[A-Za-z\u00C0-\u024F]/;

  function normalizeText(text) {
    if (!text) return '';
    return text.replace(/\s+/g, ' ').trim();
  }

  function stripCodeAndUrls(text) {
    if (!text) return '';
    return text
      .replace(/https?:\/\/[^\s]+/g, '')
      .replace(/`[^`]+`/g, '')
      .replace(/```[\s\S]*?```/g, '')
      .trim();
  }

  function classifyDirection(text) {
    const clean = stripCodeAndUrls(normalizeText(text));
    if (!clean) return null;

    // Scan for first strong directional character
    for (let i = 0; i < clean.length; i++) {
      const char = clean[i];
      if (RTL_RE.test(char)) return 'rtl';
      if (LTR_RE.test(char)) return 'ltr';
    }
    return null;
  }

  window.__AGY_RTL_SHARED = {
    RTL_RE,
    LTR_RE,
    STRONG_RE,
    normalizeText,
    stripCodeAndUrls,
    classifyDirection
  };

  return window.__AGY_RTL_SHARED;
})();
'@
}
