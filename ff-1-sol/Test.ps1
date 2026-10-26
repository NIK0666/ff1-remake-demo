param(
    [string]$EnginePath,
    [switch]$Visual
)
$ErrorActionPreference = 'Stop'
if (-not $EnginePath) {
    $packagePath = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe'
    $installedEngine = Get-ChildItem -LiteralPath $packagePath -Filter '*_console.exe' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($installedEngine) { $EnginePath = $installedEngine.FullName }
    else { $EnginePath = (Get-Command godot -ErrorAction Stop).Source }
}
$rules = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'data\game.json') | ConvertFrom-Json
$logName = if ($Visual) { 'visual-validation.log' } else { 'validation.log' }
$logPath = Join-Path $PSScriptRoot ('docs\' + $logName)
$runtimeArguments = @('--path', $PSScriptRoot, '--quit-after', [string]$rules.test.max_frames, '--log-file', $logPath)
if (-not $Visual) { $runtimeArguments += '--headless' }
$runtimeArguments += @('--', '--self-test')
if ($Visual) { $runtimeArguments += '--screenshots' }
& $EnginePath @runtimeArguments
if ($LASTEXITCODE -ne $rules.n.zero) { exit $LASTEXITCODE }
$log = Get-Content -Raw -LiteralPath $logPath
if ($log -notmatch 'ACCEPTANCE: (\d+)/\1 passed' -or $log -match 'SCRIPT ERROR:|ERROR: FAIL:') {
    throw 'Acceptance run did not finish successfully. See the validation log.'
}
