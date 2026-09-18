function Get-AntigravityRtlSharedHelpers {
    @'
(function () {
  const RTL_RE = /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g;
  const LTR_RE = /[A-Za-z\u00C0-\u024F]/g;
  const STRONG_RE = /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFFA-Za-z\u00C0-\u024F]/;

  // Keep the classifier useful for scripts outside the Hebrew/Arabic ranges
  // covered by the legacy regex. This is code-point based so astral scripts
  // such as Adlam are handled as one character rather than two UTF-16 units.
  const RTL_CODE_POINT_RANGES = [
    [0x0590, 0x05ff], [0x0600, 0x06ff], [0x0700, 0x074f], [0x0750, 0x077f],
    [0x0780, 0x07bf], [0x07c0, 0x07ff], [0x0800, 0x083f], [0x0840, 0x085f],
    [0x0860, 0x086f], [0x0870, 0x089f], [0x08a0, 0x08ff], [0xfb1d, 0xfb4f],
    [0xfb50, 0xfdff], [0xfe70, 0xfeff], [0x10800, 0x1083f], [0x10840, 0x1085f],
    [0x10a00, 0x10a5f], [0x10e60, 0x10e7f], [0x1e800, 0x1e8df], [0x1e900, 0x1e95f],
    [0x1ee00, 0x1eeff]
  ];

  function isRtlCodePoint(codePoint) {
    for (const [start, end] of RTL_CODE_POINT_RANGES) {
      if (codePoint >= start && codePoint <= end) return true;
    }
    return false;
  }

  function hasRtlCodePoint(text) {
    const value = String(text || '');
    for (let index = 0; index < value.length;) {
      const codePoint = value.codePointAt(index);
      if (isRtlCodePoint(codePoint)) return true;
      index += codePoint > 0xffff ? 2 : 1;
    }
    return false;
  }

  function firstStrongDirection(text) {
    const value = String(text || '');
    for (let index = 0; index < value.length;) {
      const codePoint = value.codePointAt(index);
      if (isRtlCodePoint(codePoint)) return 'rtl';
      if ((codePoint >= 0x41 && codePoint <= 0x5a) || (codePoint >= 0x61 && codePoint <= 0x7a)) return 'ltr';
      index += codePoint > 0xffff ? 2 : 1;
    }
    return null;
  }

  function lastStrongDirection(text) {
    const value = String(text || '');
    let last = null;
    for (let index = 0; index < value.length;) {
      const codePoint = value.codePointAt(index);
      if (isRtlCodePoint(codePoint)) {
        last = 'rtl';
      } else if ((codePoint >= 0x41 && codePoint <= 0x5a) || (codePoint >= 0x61 && codePoint <= 0x7a)) {
        last = 'ltr';
      }
      index += codePoint > 0xffff ? 2 : 1;
    }
    return last;
  }

  function proseDirection(text) {
    const value = String(text || '');
    // Any Hebrew/Arabic/Persian content makes the prose block RTL, even when
    // the first visible run is an English link, project name, or label. Keep
    // English-only prose LTR and let the browser's bidi algorithm isolate the
    // embedded Latin runs inside an RTL block.
    if (hasRtlCodePoint(value)) return 'rtl';
    return firstStrongDirection(value);
  }

  function hasMixedTerminalLtrTail(text) {
    const value = String(text || '');
    return firstStrongDirection(value) === 'rtl'
      && hasRtlCodePoint(value)
      && lastStrongDirection(value) === 'ltr';
  }

  function stripLeadingLtr(text) {
    return String(text || '')
      .replace(/^[\s]*(?:[\w.\-]+\.[\w]{1,5})\s*/g, '')
      .replace(/https?:\/\/\S+/g, '')
      .replace(/[\w.\-]+[\/\\][\w.\-\/\\]+/g, '')
      .replace(/`[^`]+`/g, '');
  }

  function normalizeText(text) {
    return String(text || '').replace(/\s+/g, ' ').trim();
  }

  function stripCodeAndUrls(text) {
    if (!text) return '';
    return String(text)
      .replace(/https?:\/\/[^\s]+/g, '')
      .replace(/`[^`]+`/g, '')
      .replace(/```[\s\S]*?```/g, '')
      .trim();
  }

  function stripDiagnosticPrefix(text) {
    return normalizeText(text)
      .replace(/^[A-Z]\d{2}\.\s*[^:\n]{1,80}:\s*/u, '')
      .replace(/^\d{1,3}\.\s*[^:\n]{1,80}:\s*/u, '')
      .trim();
  }

  function getMeaningfulText(input, skipSelector) {
    if (!input) return '';
    if (typeof input === 'string') return stripDiagnosticPrefix(stripCodeAndUrls(input));

    const clone = input.cloneNode(true);
    if (skipSelector) {
      for (const technical of clone.querySelectorAll(skipSelector)) {
        technical.remove();
      }
    }
    return stripDiagnosticPrefix(stripCodeAndUrls(clone.innerText || clone.textContent || ''));
  }

  function classifyDirection(input, skipSelector) {
    const normalized = getMeaningfulText(input, skipSelector);
    if (!normalized) return null;

    // A single Hebrew/Arabic character is enough to make the prose block RTL.
    // The browser's bidi algorithm keeps embedded English runs LTR, while
    // this block-level direction gives the mixed sentence the correct edge.
    if (hasRtlCodePoint(normalized)) return 'rtl';

    return 'ltr';
  }

  function cellDirection(text) {
    if (hasRtlCodePoint(text)) return 'rtl';
    if (firstStrongDirection(text) === 'ltr') return 'ltr';
    return null;
  }

  function majorityDirection(directions) {
    let rtl = 0;
    let ltr = 0;
    for (const direction of directions || []) {
      if (direction === 'rtl') rtl += 1;
      if (direction === 'ltr') ltr += 1;
    }
    return rtl > ltr ? 'rtl' : ltr > rtl ? 'ltr' : null;
  }

  function tableDirectionFromCells(headerDirections, firstColumnDirections) {
    if (headerDirections?.[0] === 'rtl' && firstColumnDirections?.[0] === 'rtl') return 'rtl';
    if (majorityDirection(headerDirections) === 'rtl') return 'rtl';
    if (majorityDirection(headerDirections) === 'ltr') return null;
    return majorityDirection(firstColumnDirections) === 'rtl' ? 'rtl' : null;
  }

  function ensureHelpers(scope) {
    const helpers = {
      RTL_RE,
      LTR_RE,
      STRONG_RE,
      RTL_CODE_POINT_RANGES,
      normalizeText,
      stripCodeAndUrls,
      stripDiagnosticPrefix,
      getMeaningfulText,
      classifyDirection,
      hasRtlCodePoint,
      isRtlCodePoint,
      firstStrongDirection,
      lastStrongDirection,
      proseDirection,
      hasMixedTerminalLtrTail,
      stripLeadingLtr,
      cellDirection,
      majorityDirection,
      tableDirectionFromCells
    };
    scope.__AGY_RTL_SHARED = helpers;
    return helpers;
  }

  return ensureHelpers(typeof window !== 'undefined' ? window : (typeof globalThis !== 'undefined' ? globalThis : this));
})();
'@
}
