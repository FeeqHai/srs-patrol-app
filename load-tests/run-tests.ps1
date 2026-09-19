param(
    [ValidateSet('quick','smoke','baseline','load','login','writes')]
    [string]$Mode = 'quick',
    [switch]$SharedPassword
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$k6Path = (Get-Command k6 -ErrorAction SilentlyContinue).Source
if (-not $k6Path) { $k6Path = Join-Path $env:ProgramFiles 'k6/k6.exe' }
if (-not (Test-Path -LiteralPath $k6Path)) { throw 'k6 was not found. Open a new PowerShell window.' }
if ($Mode -eq 'writes' -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'patrol-fixture.local.json'))) {
    throw 'First prepare patrol-fixture.local.json using the example and README. No requests were sent.'
}
$accountList = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'accounts.json') -Raw | ConvertFrom-Json
$accountList = @($accountList)
if (-not $accountList.Count) { throw 'accounts.json must contain at least one test account.' }
foreach ($account in $accountList) {
    if ($account.email -isnot [string] -or [string]::IsNullOrWhiteSpace($account.email) -or
        $account.role -isnot [string] -or $account.label -isnot [string]) {
        throw 'Each accounts.json entry must contain one email, role and label.'
    }
}
$credentials = @()
$sharedSecret = $null
$savedEnvironment = @{}
$envNames = @('IRONDA_CREDENTIALS','IRONDA_MODE','IRONDA_OUTPUT','K6_WEB_DASHBOARD','K6_WEB_DASHBOARD_PORT','K6_WEB_DASHBOARD_EXPORT','K6_WEB_DASHBOARD_PERIOD')
foreach ($name in $envNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
Push-Location $PSScriptRoot
try {
    if ($SharedPassword) { $sharedSecret = Read-Host 'Shared password for these five test accounts' -AsSecureString }
    foreach ($account in $accountList) {
        $secret = if ($SharedPassword) { $sharedSecret } else { Read-Host ('Password for ' + $account.email) -AsSecureString }
        $credential = [PSCredential]::new($account.email,$secret)
        $credentials += @{email=$account.email; password=$credential.GetNetworkCredential().Password}
    }
    $env:IRONDA_CREDENTIALS = ConvertTo-Json -InputObject @($credentials) -Compress
    $credentialCheck = ConvertFrom-Json -InputObject $env:IRONDA_CREDENTIALS
    if (@($credentialCheck).Count -ne $accountList.Count) { throw 'Credential count does not match accounts.json; no test was started.' }
    Write-Host ('Prepared credentials for ' + $accountList.Count + ' separate test accounts.')
    $phases = if ($Mode -eq 'quick') { @('smoke','load','login') } else { @($Mode) }
    $overallCode = 0
    foreach ($phase in $phases) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $outputFolder = Join-Path $PSScriptRoot ('results/' + $stamp + '-' + $phase)
        New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
        $env:IRONDA_MODE = $phase
        $env:IRONDA_OUTPUT = $outputFolder.Replace('\','/')
        $env:K6_WEB_DASHBOARD = 'true'
        $env:K6_WEB_DASHBOARD_PORT = '-1'
        $env:K6_WEB_DASHBOARD_PERIOD = '1s'
        $env:K6_WEB_DASHBOARD_EXPORT = Join-Path $outputFolder 'dashboard.html'
        $scriptFile = switch ($phase) { 'writes' {'patrol-write.js'} 'login' {'login-load.js'} default {'ironda-suite.js'} }
        $sourceFiles = @('common.js','catalog.js','ironda-suite.js','login-load.js','patrol-write.js','accounts.json','run-tests.ps1')
        $hashes = @($sourceFiles | ForEach-Object { $h=Get-FileHash -LiteralPath $_ -Algorithm SHA256; @{file=$_;sha256=$h.Hash} })
        $manifest = @{started=(Get-Date).ToString('o');phase=$phase;hosting='Lecturer-provided cPanel hosting';base_url='https://api.ironda.app/srs_api/';k6=(& $k6Path version | Out-String).Trim();source_hashes=$hashes;accounts=@($accountList | Select-Object label,role);script=$scriptFile}
        $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outputFolder 'run-manifest.json') -Encoding UTF8
        foreach ($sourceFile in $sourceFiles) { Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $outputFolder $sourceFile) }
        Write-Host "Running $phase. Results: $outputFolder"
        & $k6Path run --no-usage-report --out ('json=' + (Join-Path $outputFolder 'metrics.json')) $scriptFile
        $runCode = $LASTEXITCODE
        @{finished=(Get-Date).ToString('o');exit_code=$runCode} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputFolder 'completion.json') -Encoding UTF8
        if ($runCode -ne 0) {
            $overallCode = $runCode
            if ($phase -eq 'smoke' -or $runCode -ne 99) {
                Write-Warning 'Stopped after failed preflight or runtime error. Keep the result folder for diagnosis.'
                break
            }
            Write-Warning 'Performance/check thresholds failed. Results were preserved; continuing remaining planned phase.'
        }
    }
    Write-Host "Finished. Overall exit code: $overallCode. Share results.md and results.json from each phase."
} finally {
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name],'Process') }
    $credentials = $null; $credential = $null; $credentialCheck = $null; $secret = $null; $sharedSecret = $null
    Pop-Location
}
