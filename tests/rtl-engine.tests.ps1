$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\antigravity\rtl-shared.ps1')
. (Join-Path $repoRoot 'src\antigravity\rtl-payload.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$sharedPayload = Get-AntigravityRtlSharedHelpers
Assert-True ($sharedPayload.Contains('RTL_CODE_POINT_RANGES')) 'Shared payload should define RTL code point ranges.'
Assert-True ($sharedPayload.Contains('hasRtlCodePoint')) 'Shared payload should expose hasRtlCodePoint helper.'
Assert-True ($sharedPayload.Contains('proseDirection')) 'Shared payload should expose proseDirection helper.'
Assert-True ($sharedPayload.Contains('tableDirectionFromCells')) 'Shared payload should expose tableDirectionFromCells helper.'
Assert-True ($sharedPayload.Contains('cellDirection')) 'Shared payload should expose cellDirection helper.'

$rtlPayload = Get-AntigravityRtlPayload
Assert-True ($rtlPayload.Contains('unicode-bidi: isolate !important;')) 'RTL style should use isolate bidi mode.'
Assert-True ($rtlPayload.Contains('table[data-agy-rtl="rtl"]')) 'RTL payload should include table direction selector.'
Assert-True ($rtlPayload.Contains('processTable')) 'RTL payload should include table processing.'
Assert-True ($rtlPayload.Contains('processLists')) 'RTL payload should include list processing.'
Assert-True ($rtlPayload.Contains('processArtifactCards')) 'RTL payload should include artifact card processing.'
Assert-True ($rtlPayload.Contains('.artifact-card[data-agy-rtl="rtl"]')) 'RTL payload should include artifact card style selector.'
Assert-True ($rtlPayload.Contains('ensureMixedLtrTail')) 'RTL payload should include mixed LTR tail isolation.'
Assert-True ($rtlPayload.Contains('data-agy-rtl-ltr-tail')) 'RTL payload should include LTR tail selector.'

$nodeCommand = Get-Command -Name node -ErrorAction SilentlyContinue
if ($nodeCommand) {
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("agy-rtl-test-{0}.js" -f ([guid]::NewGuid().ToString('N')))
    try {
        $nodeTestCode = @"
const vm = require('vm');
const context = { window: {} };
vm.createContext(context);
vm.runInContext($([Convert]::ToString($sharedPayload) | ConvertTo-Json), context);

const helpers = context.window.__AGY_RTL_SHARED;
if (!helpers) throw new Error('Helpers not exported to window.__AGY_RTL_SHARED');

// Test basic classification
if (helpers.classifyDirection('Hello world') !== 'ltr') throw new Error('Expected "ltr" for pure English');
if (helpers.classifyDirection('שלום עולם') !== 'rtl') throw new Error('Expected "rtl" for pure Hebrew');
if (helpers.classifyDirection('Please review שלום world') !== 'rtl') throw new Error('Expected "rtl" for mixed sentence containing Hebrew');
if (helpers.classifyDirection('נוסף מרווח תחת Projects.') !== 'rtl') throw new Error('Expected "rtl" for Hebrew with English token');
if (helpers.classifyDirection('1. בממשק המשתמש (UI):') !== 'rtl') throw new Error('Expected "rtl" for Hebrew numbered header');
if (helpers.classifyProseDirection('1. בממשק המשתמש (UI):') !== 'rtl') throw new Error('Expected "rtl" prose for Hebrew numbered header');
if (!helpers.hasMixedTerminalLtrTail('1. בממשק המשתמש (UI):')) throw new Error('Expected mixed terminal LTR tail for (UI):');
if (helpers.stripDiagnosticPrefix('E01. System error: בדיקה עברה') !== 'בדיקה עברה') throw new Error('Expected English diagnostic prefix to be stripped');
if (helpers.stripDiagnosticPrefix('1. בממשק המשתמש (UI):') !== '1. בממשק המשתמש (UI):') throw new Error('Expected Hebrew numbered header not to be stripped as diagnostic');

// Test proseDirection
if (helpers.proseDirection('Hello world') !== 'ltr') throw new Error('Expected "ltr" prose for English');
if (helpers.proseDirection('שלום עולם') !== 'rtl') throw new Error('Expected "rtl" prose for Hebrew');
if (helpers.proseDirection('Please review שלום') !== 'rtl') throw new Error('Expected "rtl" prose for mixed with Hebrew');

// Test code points (Astral Plane 1 - Adlam 0x1E900)
if (!helpers.isRtlCodePoint(0x1E900)) throw new Error('Expected Adlam 0x1E900 to be recognized as RTL');
if (!helpers.hasRtlCodePoint(String.fromCodePoint(0x1E900))) throw new Error('Expected Adlam string to have RTL code point');

// Test table direction
if (helpers.tableDirectionFromCells(['rtl', 'ltr'], ['rtl']) !== 'rtl') throw new Error('Expected table with RTL header to be RTL');
if (helpers.tableDirectionFromCells(['ltr', 'ltr'], ['ltr']) !== null) throw new Error('Expected table with LTR headers to be neutral');

console.log('All Node.js RTL engine tests passed.');
"@
        Set-Content -LiteralPath $tempScript -Value $nodeTestCode -Encoding UTF8
        $nodeOut = & $nodeCommand.Path $tempScript 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "Node.js test execution failed:`n$nodeOut"
        }
        Write-Host $nodeOut.Trim()
    } finally {
        if (Test-Path -LiteralPath $tempScript) {
            Remove-Item -LiteralPath $tempScript -Force
        }
    }
}

Write-Host "rtl-engine.tests.ps1 passed successfully." -ForegroundColor Green
