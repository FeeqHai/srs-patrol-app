param(
    [string]$BaseUrl = 'http://127.0.0.1/srs_api',
    [int[]]$ConcurrentUsers = @(1, 10, 25, 50, 75, 100, 150, 200),
    [int]$RequestsPerUser = 20,
    [string]$OutputDirectory = "$PSScriptRoot\results\local_preliminary"
)

$ErrorActionPreference = 'Stop'
$ab = 'C:\xampp\apache\bin\ab.exe'
if (-not (Test-Path -LiteralPath $ab)) {
    throw 'ApacheBench was not found in the expected XAMPP directory.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$endpoint = "$($BaseUrl.TrimEnd('/'))/auth/get_locations.php?level=states"

function Read-Metric([string]$Text, [string]$Pattern, [string]$Name) {
    $match = [regex]::Match($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) { throw "Unable to parse $Name from ApacheBench output." }
    return $match.Groups[1].Value
}

function Invoke-ApacheBench([int]$Requests, [int]$Concurrency, [string]$Url) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ab
    $startInfo.Arguments = "-n $Requests -c $Concurrency -k -r `"$Url`""
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($startInfo)
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "ApacheBench failed with exit code $($process.ExitCode): $standardError"
    }
    return "$standardOutput`n$standardError"
}

# Warm the PHP opcode path and database connection before recording stages.
Invoke-ApacheBench 20 1 $endpoint | Out-Null

$results = foreach ($users in $ConcurrentUsers) {
    $requests = [Math]::Max(200, $users * $RequestsPerUser)
    $raw = Invoke-ApacheBench $requests $users $endpoint
    $complete = [int](Read-Metric $raw '^Complete requests:\s+(\d+)' 'complete requests')
    $failed = [int](Read-Metric $raw '^Failed requests:\s+(\d+)' 'failed requests')
    $requestsPerSecond = [double](Read-Metric $raw '^Requests per second:\s+([0-9.]+)' 'requests per second')
    $p95Ms = [double](Read-Metric $raw '^\s*95%\s+(\d+)' 'p95 latency')
    $errorRate = if ($complete -eq 0) { 1.0 } else { $failed / $complete }
    $stagePass = $p95Ms -lt 2000 -and $errorRate -lt 0.01
    $rawPath = Join-Path $OutputDirectory ("ab_{0:D3}_users.txt" -f $users)
    Set-Content -LiteralPath $rawPath -Value $raw -Encoding utf8

    [pscustomobject]@{
        evidence_scope = 'LOCAL_PRELIMINARY_READ_ONLY'
        concurrent_users = $users
        requested_requests = $requests
        completed_requests = $complete
        failed_requests = $failed
        error_rate_percent = [Math]::Round($errorRate * 100, 4)
        p95_ms = $p95Ms
        requests_per_second = $requestsPerSecond
        regular_api_threshold_pass = $stagePass
        generated_at = (Get-Date).ToString('o')
    }
}

$csvPath = Join-Path $OutputDirectory 'local_preliminary_capacity.csv'
$results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
$results | Format-Table -AutoSize
Write-Output "RESULT_CSV=$csvPath"
Write-Output 'NOTICE=These same-machine, read-only results validate the harness only and must not be reported as production capacity.'
