# Agent BETA Loop
# Main agent loop - continuous work, reading tasks and messages from GitHub

param(
    [string]$GitToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = "C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow",
    [int]$SyncInterval = 5
)

$agentName = "BETA"
$roleDescription = "Verification and validation"
$outputDir = Join-Path $RepoPath "output"
$outputLog = Join-Path $outputDir "agent-beta-log.md"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if (-not (Test-Path $outputLog)) {
    $logContent = "# Agent BETA - Work Log`n`n**Role:** $roleDescription`n**Start:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n---`n`n## Work History`n`n"
    Set-Content -Path $outputLog -Value $logContent -Encoding UTF8 -Force
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "AGENT BETA START" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Path: $RepoPath" -ForegroundColor Gray
Write-Host "Sync interval: ${SyncInterval}s" -ForegroundColor Gray
Write-Host ""

$iterationCount = 0
$logEntriesAdded = 0

while ($true) {
    $iterationCount++
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "[$timestamp] Git PULL (iteration #$iterationCount)..." -ForegroundColor Gray -NoNewline
    
    cd $RepoPath
    
    git config user.email "agent@rojagentow.local" 2>&1 | Out-Null
    git config user.name "Agent $agentName" 2>&1 | Out-Null
    
    $jitter = Get-Random -Minimum 0 -Maximum 3
    Start-Sleep -Seconds $jitter
    
    git pull origin master --quiet 2>&1 | Out-Null
    
    Write-Host " OK" -ForegroundColor Green
    
    Write-Host "[$timestamp] Reading JSON files..." -ForegroundColor Gray -NoNewline
    
    $taskQueuePath = Join-Path $RepoPath "task-queue.json"
    $messagesPath = Join-Path $RepoPath "agent-messages.json"
    
    if (-not (Test-Path $taskQueuePath)) {
        Write-Host " MISSING" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    try {
        $taskQueue = Get-Content $taskQueuePath -Raw | ConvertFrom-Json -ErrorAction Stop
        $messages = Get-Content $messagesPath -Raw | ConvertFrom-Json -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    } catch {
        Write-Host " ERROR" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $criticalMsg = $messages.messages | Where-Object { $_.priority -eq "critical" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($criticalMsg) {
        Write-Host "[$timestamp] CRITICAL: $($criticalMsg.subject)" -ForegroundColor Red
        $logEntry = "### [$fullTimestamp] CRITICAL`nFrom: $($criticalMsg.from)`nSubject: $($criticalMsg.subject)`nAction: $($criticalMsg.action)`n`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $highMsg = $messages.messages | Where-Object { $_.priority -eq "high" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($highMsg) {
        Write-Host "[$timestamp] HIGH: $($highMsg.subject)" -ForegroundColor Yellow
        $logEntry = "### [$fullTimestamp] HIGH PRIORITY`nFrom: $($highMsg.from)`nSubject: $($highMsg.subject)`nAction: $($highMsg.action)`n`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $nextPrompt = $taskQueue.next_prompt_for.$agentName
    if ($nextPrompt) {
        Write-Host "[$timestamp] TASK: Assigned work..." -ForegroundColor Green
        $logEntry = "### [$fullTimestamp] TASK ASSIGNED`nPrompt: $nextPrompt`n`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $mediumMsg = $messages.messages | Where-Object { $_.priority -eq "medium" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($mediumMsg) {
        Write-Host "[$timestamp] MEDIUM: $($mediumMsg.subject)" -ForegroundColor DarkYellow
        $logEntry = "### [$fullTimestamp] MEDIUM PRIORITY`nFrom: $($mediumMsg.from)`nSubject: $($mediumMsg.subject)`n`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    Write-Host "[$timestamp] Waiting for instructions..." -ForegroundColor Gray
    
    if ($logEntriesAdded -gt 0) {
        Write-Host "[$timestamp] Git PUSH - sending log..." -ForegroundColor Gray -NoNewline
        
        $jitterPush = Get-Random -Minimum 0 -Maximum 3
        Start-Sleep -Seconds $jitterPush
        
        git add "output/agent-beta-log.md" 2>&1 | Out-Null
        git commit -m "Agent BETA log update - iteration $iterationCount" --quiet 2>&1 | Out-Null
        git push origin master --quiet 2>&1 | Out-Null
        
        Write-Host " OK" -ForegroundColor Green
        $logEntriesAdded = 0
    }
    
    Start-Sleep -Seconds $SyncInterval
}
