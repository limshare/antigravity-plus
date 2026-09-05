function Get-AntigravityPayloadBundle {
    $shared = Get-AntigravityRtlSharedHelpers
    $rtl = Get-AntigravityRtlPayload
    $ui = Get-AntigravityUiEnhancementsPayload

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
})();
"@
}
