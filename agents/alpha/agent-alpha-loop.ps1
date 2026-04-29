# Agent ALPHA Loop
# Pętla główna agenta ALPHA — pracuje bez przerwy, czyta zadania i komunikaty z GitHub

param(
    [string]$GitToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = "C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow",
    [int]$SyncInterval = 5
)

$agentName = "ALPHA"
$roleDescription = "Analityk — głębokie badania matematyczne"
$outputLog = Join-Path $RepoPath "output\agent-alpha-log.md"

# Inicjalizacja loga
if (-not (Test-Path $outputLog)) {
    $logContent = @"
# Agent ALPHA — Log Pracy

**Rola:** $roleDescription
**Start:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

## Historia pracy

"@
    Set-Content -Path $outputLog -Value $logContent -Encoding UTF8
}

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🤖 AGENT ALPHA START" -ForegroundColor Yellow
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
    
    # ─────────────────────────────────────────────────────────────
    # KROK 1: Synchronizacja z GitHub
    # ─────────────────────────────────────────────────────────────
    
    Write-Host "[$timestamp] 🔄 Iteracja #$iterationCount — Git PULL..." -ForegroundColor Gray -NoNewline
    
    cd $RepoPath
    
    # Konfiguracja gita
    git config user.email "agent@rojagentow.local" 2>&1 | Out-Null
    git config user.name "Agent $agentName" 2>&1 | Out-Null
    
    # Pull z jitteryem (random delay 0-3s)
    $jitter = Get-Random -Minimum 0 -Maximum 3
    Start-Sleep -Seconds $jitter
    
    $pullOutput = git pull origin master --quiet 2>&1
    
    Write-Host " ✅" -ForegroundColor Green
    
    # ─────────────────────────────────────────────────────────────
    # KROK 2: Czytaj pliki konfiguracyjne
    # ─────────────────────────────────────────────────────────────
    
    Write-Host "[$timestamp] 📖 Czytam: task-queue.json, agent-messages.json..." -ForegroundColor Gray -NoNewline
    
    $taskQueuePath = Join-Path $RepoPath "task-queue.json"
    $messagesPath = Join-Path $RepoPath "agent-messages.json"
    
    if (-not (Test-Path $taskQueuePath)) {
        Write-Host " ❌ (task-queue nie znaleziony)" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    try {
        $taskQueue = Get-Content $taskQueuePath -Raw | ConvertFrom-Json -ErrorAction Stop
        $messages = Get-Content $messagesPath -Raw | ConvertFrom-Json -ErrorAction Stop
        Write-Host " ✅" -ForegroundColor Green
    } catch {
        Write-Host " ❌ (błąd JSON)" -ForegroundColor Red
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # ─────────────────────────────────────────────────────────────
    # KROK 3: Priorytet — sprawdź CRITICAL wiadomości (od USER)
    # ─────────────────────────────────────────────────────────────
    
    $criticalMsg = $messages.messages | Where-Object { 
        $_.priority -eq "critical" -and $_.to -contains $agentName 
    } | Select-Object -First 1
    
    if ($criticalMsg) {
        Write-Host "[$timestamp] 🔴 CRITICAL: $($criticalMsg.subject)" -ForegroundColor Red
        Write-Host "           → Aktualizuję log..." -ForegroundColor Yellow
        
        $logEntry = @"
### [$fullTimestamp] 🔴 CRITICAL MESSAGE
- Od: $($criticalMsg.from)
- Priorytet: CRITICAL
- Temat: $($criticalMsg.subject)
- Treść: $($criticalMsg.content)
- Akcja: $($criticalMsg.action)

"@
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # ─────────────────────────────────────────────────────────────
    # KROK 4: Priorytet — sprawdź HIGH wiadomości (od kolegów)
    # ─────────────────────────────────────────────────────────────
    
    $highMsg = $messages.messages | Where-Object { 
        $_.priority -eq "high" -and $_.to -contains $agentName 
    } | Select-Object -First 1
    
    if ($highMsg) {
        Write-Host "[$timestamp] 🟠 HIGH: $($highMsg.subject)" -ForegroundColor Yellow
        Write-Host "           → Aktualizuję log..." -ForegroundColor Cyan
        
        $logEntry = @"
### [$fullTimestamp] 🟠 HIGH PRIORITY MESSAGE
- Od: $($highMsg.from)
- Priorytet: HIGH
- Temat: $($highMsg.subject)
- Treść: $($highMsg.content)
- Akcja: $($highMsg.action)

"@
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # ─────────────────────────────────────────────────────────────
    # KROK 5: Priorytet — sprawdź główne ZADANIA (NORMAL)
    # ─────────────────────────────────────────────────────────────
    
    $nextPrompt = $taskQueue.next_prompt_for.$agentName
    
    if ($nextPrompt) {
        Write-Host "[$timestamp] 🟢 TASK: Mam zadanie dla mnie..." -ForegroundColor Green
        Write-Host "           → Aktualizuję log..." -ForegroundColor Cyan
        
        $logEntry = @"
### [$fullTimestamp] 🟢 NORMAL TASK
- Prompt: $nextPrompt
- Status: Czekam na Twoje polecenie (użytkownik może zmienić)

"@
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # ─────────────────────────────────────────────────────────────
    # KROK 6: Priorytet — sprawdź MEDIUM wiadomości (feedback)
    # ─────────────────────────────────────────────────────────────
    
    $mediumMsg = $messages.messages | Where-Object { 
        $_.priority -eq "medium" -and $_.to -contains $agentName 
    } | Select-Object -First 1
    
    if ($mediumMsg) {
        Write-Host "[$timestamp] 🟡 MEDIUM: $($mediumMsg.subject)" -ForegroundColor DarkYellow
        Write-Host "           → Aktualizuję log..." -ForegroundColor Cyan
        
        $logEntry = @"
### [$fullTimestamp] 🟡 MEDIUM PRIORITY MESSAGE
- Od: $($mediumMsg.from)
- Temat: $($mediumMsg.subject)
- Treść: $($mediumMsg.content)

"@
        Add-Content -Path $outputLog -Value $logEntry -Encoding UTF8
        $logEntriesAdded++
        
        Start-Sleep -Seconds $SyncInterval
        continue
    }
    
    # ─────────────────────────────────────────────────────────────
    # KROK 7: Czekaj — brak zadań
    # ─────────────────────────────────────────────────────────────
    
    Write-Host "[$timestamp] ⏳ Czekam na polecenia..." -ForegroundColor Gray
    
    # ─────────────────────────────────────────────────────────────
    # KROK 8: Git PUSH — aktualizuje log
    # ─────────────────────────────────────────────────────────────
    
    if ($logEntriesAdded -gt 0) {
        Write-Host "[$timestamp] 📤 Git PUSH — wysyłam log ($logEntriesAdded wpisów)..." -ForegroundColor Gray -NoNewline
        
        $jitterPush = Get-Random -Minimum 0 -Maximum 3
        Start-Sleep -Seconds $jitterPush
        
        git add output/agent-alpha-log.md 2>&1 | Out-Null
        git commit -m "Agent ALPHA log update — iteracja #$iterationCount" --quiet 2>&1 | Out-Null
        git push origin master --quiet 2>&1 | Out-Null
        
        Write-Host " ✅" -ForegroundColor Green
        $logEntriesAdded = 0
    }
    
    # ─────────────────────────────────────────────────────────────
    # CZEKAJ na następny cykl
    # ─────────────────────────────────────────────────────────────
    
    Start-Sleep -Seconds $SyncInterval
}
