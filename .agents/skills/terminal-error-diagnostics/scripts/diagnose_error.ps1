param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [string]$Cwd
)

$originalLocation = Get-Location

if ($Cwd) {
    if (Test-Path $Cwd) {
        Set-Location $Cwd
        Write-Host "Set working directory to: $Cwd" -ForegroundColor Gray
    } else {
        Write-Warning "Directory not found: $Cwd. Running in current directory."
    }
}

Write-Host "Executing diagnostic test command: $Command" -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

$startTime = Get-Date

try {
    # Initialize process info
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -Command `"$Command`""
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    # Start the process
    $started = $process.Start()
    if (-not $started) {
        throw "Failed to start the diagnostics process."
    }

    # Asynchronously read output to prevent blockages
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    # Wait for process to exit
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    $endTime = Get-Date
    $elapsed = ($endTime - $startTime).TotalSeconds

    $color = "Red"
    if ($exitCode -eq 0) {
        $color = "Green"
    }

    Write-Host "`n=== DIAGNOSTICS COMPLETED IN $($elapsed.ToString("F2")) SECONDS ===" -ForegroundColor Cyan
    Write-Host "Exit Code: $exitCode" -ForegroundColor $color
    
    if ($stdout.Trim()) {
        Write-Host "`n[Stdout Output]" -ForegroundColor Green
        Write-Output $stdout
    }
    
    if ($stderr.Trim()) {
        Write-Host "`n[Stderr Error Output]" -ForegroundColor Red
        Write-Error $stderr
    }

} catch {
    Write-Error "An error occurred during diagnostics: $_"
} finally {
    Set-Location $originalLocation
}
