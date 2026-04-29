# Agent BETA Loop
# Pętla główna agenta BETA — pracuje bez przerwy, czyta zadania i komunikaty z GitHub

param(
    [string]$GitToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = "C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow",
    [int]$SyncInterval = 5
)

$agentName = "BETA"
$roleDescription = "Weryfikator — sprawdzanie i walidacja wyników"
$outputLog = Join-Path $RepoPath "output\agent-beta-log.md"

# Inicjalizacja loga
if (-not (Test-Path $outputLog)) {
    $logContent = @"
# Agent BETA — Log Pracy

**Rola:** $roleDescription
**Start:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

## Historia pracy

"@
    Set-Content -Path $outputLog -Value $logContent -Encoding UTF8
}

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🤖 AGENT BETA START" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📍 Ścieżka: $RepoPath" -ForegroundColor Gray
Write-Host "⏱️  Interwał sync: ${SyncInterval}s" -ForegroundColor Gray
Write-Host ""

$iterationCount = 0
$logEntriesAdded = 0

while ($true) {
    $iterationCount++
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "[$timestamp] 🔄 Iteracja #$iterationCount — Git PULL..." -ForegroundColor Gray -NoNewline
    
    cd $RepoPath
    
    git config user.email "agent@rojagentow.local" 2>&1 | Out-Null
    git config user.name "Agent $agentName" 2>&1 | Out-Null
    
    $jitter = Get-Random -Minimum 0 -Maximum 3
    Start-Sleep -Seconds $jitter
    
    git pull origin master --quiet 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
    
    Write-Host "[$timestamp] 📖 Czytam: task-queue.json, agent-messages.json..." -ForegroundColor Gray -NoNewline
    
    $taskQueuePath = Join-Path $RepoPath "task-queue.json"
    $messagesPath = Join-Path $RepoPath "agent-messages.json"
    
    if (-not (Test-Path $taskQueuePath)) {
        Write-Host " ❌" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    try {
        $taskQueue = Get-Content $taskQueuePath -Raw | ConvertFrom-Json -ErrorAction Stop
        $messages = Get-Content $messagesPath -Raw | ConvertFrom-Json -ErrorAction Stop
        Write-Host " ✅" -ForegroundColor Green
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # Sprawdzanie priorytetów
    $criticalMsg = $messages.messages | Where-Object { $_.priority -eq "critical" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($criticalMsg) {
        Write-Host "[$timestamp] 🔴 CRITICAL: $($criticalMsg.subject)" -ForegroundColor Red
        $logEntry = "### [$fullTimestamp] 🔴 CRITICAL`n- Temat: $($criticalMsg.subject)`n- Akcja: $($criticalMsg.action)`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $highMsg = $messages.messages | Where-Object { $_.priority -eq "high" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($highMsg) {
        Write-Host "[$timestamp] 🟠 HIGH: $($highMsg.subject)" -ForegroundColor Yellow
        $logEntry = "### [$fullTimestamp] 🟠 HIGH`n- Temat: $($highMsg.subject)`n- Akcja: $($highMsg.action)`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $nextPrompt = $taskQueue.next_prompt_for.$agentName
    if ($nextPrompt) {
        Write-Host "[$timestamp] 🟢 TASK: Mam zadanie..." -ForegroundColor Green
        $logEntry = "### [$fullTimestamp] 🟢 TASK`n- Prompt: $nextPrompt`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    $mediumMsg = $messages.messages | Where-Object { $_.priority -eq "medium" -and $_.to -contains $agentName } | Select-Object -First 1
    if ($mediumMsg) {
        Write-Host "[$timestamp] 🟡 MEDIUM: $($mediumMsg.subject)" -ForegroundColor DarkYellow
        $logEntry = "### [$fullTimestamp] 🟡 MEDIUM`n- Temat: $($mediumMsg.subject)`n"
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    Write-Host "[$timestamp] ⏳ Czekam na polecenia..." -ForegroundColor Gray
    
    if ($logEntriesAdded -gt 0) {
        Write-Host "[$timestamp] 📤 Git PUSH — wysyłam log..." -ForegroundColor Gray -NoNewline
        
        $jitterPush = Get-Random -Minimum 0 -Maximum 3
        Start-Sleep -Seconds $jitterPush
        
        git add output/agent-beta-log.md 2>&1 | Out-Null
        git commit -m "Agent BETA log update — iteracja #$iterationCount" --quiet 2>&1 | Out-Null
        git push origin master --quiet 2>&1 | Out-Null
        
        Write-Host " ✅" -ForegroundColor Green
        $logEntriesAdded = 0
    }
    
    Start-Sleep -Seconds $SyncInterval
}
