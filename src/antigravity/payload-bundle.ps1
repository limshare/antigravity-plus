function Get-AntigravityPayloadBundle {
    $shared = Get-AntigravityRtlSharedHelpers
    $rtl = Get-AntigravityRtlPayload
    $ui = Get-AntigravityUiEnhancementsPayload
    $badge = Get-AntigravityContextBadgePayload
    $sidebar = Get-AntigravitySidebarEnhancementsPayload
    $composerTopBar = Get-AntigravityComposerTopBarPayload
    $newWindow = Get-AntigravityNewWindowButtonPayload
    $translator = Get-AntigravityThinkingTranslatorPayload
    $actionsCollapsible = Get-AntigravityActionsCollapsiblePayload

    return @"
// Antigravity Plus Runtime Bundle
(function() {
    try {
        $shared
    } catch(e) {
        console.error('[Antigravity Plus] Shared helpers error:', e);
    }
    try {
        $rtl
    } catch(e) {
        console.error('[Antigravity Plus] RTL payload error:', e);
    }
    try {
        $ui
    } catch(e) {
        console.error('[Antigravity Plus] UI payload error:', e);
    }
    try {
        $badge
    } catch(e) {
        console.error('[Antigravity Plus] Badge payload error:', e);
    }
    try {
        $sidebar
    } catch(e) {
        console.error('[Antigravity Plus] Sidebar payload error:', e);
    }
    try {
        $composerTopBar
    } catch(e) {
        console.error('[Antigravity Plus] Composer top bar payload error:', e);
    }
    try {
        $newWindow
    } catch(e) {
        console.error('[Antigravity Plus] New window button payload error:', e);
    }
    try {
        $translator
    } catch(e) {
        console.error('[Antigravity Plus] Thinking translator payload error:', e);
    }
    try {
        $actionsCollapsible
    } catch(e) {
        console.error('[Antigravity Plus] Actions collapsible payload error:', e);
    }
    try {
        window.__GEMINI_PLUS_INJECTION_READY = true;
    } catch(e) {}
})();
"@
}
