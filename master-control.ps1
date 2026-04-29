# Master Control — Sterownik systemu multi-agent
# Używaj tego aby: dodawać zadania, wysyłać komunikaty, uruchamiać agentów

param(
    [string]$GitToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = "C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow"
)

$env:GITHUB_TOKEN = $GitToken

function Show-Menu {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor White
    Write-Host "          MASTER CONTROL — STEROWNIK AGENTÓW" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] 📋 Dodaj zadanie dla agenta" -ForegroundColor Cyan
    Write-Host "  [2] 💬 Wyślij pilną wiadomość (CRITICAL)" -ForegroundColor Cyan
    Write-Host "  [3] 🚀 Uruchom agenta w nowym terminalu" -ForegroundColor Cyan
    Write-Host "  [4] 📊 Pokaż status agentów" -ForegroundColor Cyan
    Write-Host "  [5] 📂 Otwórz folder projektu" -ForegroundColor Cyan
    Write-Host "  [6] 🔄 Zsynchronizuj z GitHub" -ForegroundColor Cyan
    Write-Host "  [7] 🔍 Pokaż logi agentów" -ForegroundColor Cyan
    Write-Host "  [0] ❌ Wyjście" -ForegroundColor Gray
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor White
}

function Add-Task {
    Write-Host ""
    Write-Host "📋 DODAJ NOWE ZADANIE" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    $taskId = Read-Host "ID zadania (np. task-002)"
    $title = Read-Host "Tytuł"
    $description = Read-Host "Opis"
    
    Write-Host ""
    Write-Host "Dla którego agenta?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] Wszyscy"
    $agentChoice = Read-Host "Wybór"
    
    $agents = @()
    if ($agentChoice -eq "1") { $agents = @("ALPHA") }
    elseif ($agentChoice -eq "2") { $agents = @("BETA") }
    elseif ($agentChoice -eq "3") { $agents = @("GAMMA") }
    elseif ($agentChoice -eq "4") { $agents = @("ALPHA", "BETA", "GAMMA") }
    
    $prompt = Read-Host "Prompt do agenta"
    
    cd $RepoPath
    
    # Czytam task-queue.json
    try {
        $taskQueue = Get-Content "task-queue.json" -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "❌ Błąd odczytania task-queue.json: $_" -ForegroundColor Red
        return
    }
    
    # Dodaję nowe zadanie
    $newTask = @{
        id = $taskId
        title = $title
        description = $description
        status = "pending"
        assigned_to = $null
        created_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $taskQueue.tasks += $newTask
    
    # Aktualizuję prompty
    foreach ($agent in $agents) {
        $taskQueue.next_prompt_for.$agent = $prompt
    }
    
    # Zapisuję
    $taskQueue | ConvertTo-Json -Depth 10 | Set-Content "task-queue.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "✅ Zadanie dodane!" -ForegroundColor Green
    Write-Host "   ID: $taskId" -ForegroundColor Cyan
    Write-Host "   Agenci: $($agents -join ', ')" -ForegroundColor Cyan
}

function Send-Message {
    Write-Host ""
    Write-Host "💬 WYŚLIJ PILNĄ WIADOMOŚĆ (CRITICAL)" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    $recipient = Read-Host "Do kogo? (ALPHA/BETA/GAMMA/ALL)"
    if ($recipient -eq "ALL") {
        $recipients = @("ALPHA", "BETA", "GAMMA")
    } else {
        $recipients = @($recipient.ToUpper())
    }
    
    $subject = Read-Host "Temat"
    $content = Read-Host "Treść"
    $action = Read-Host "Akcja (np. weź task-xyz)"
    
    cd $RepoPath
    
    # Czytam agent-messages.json
    $messages = Get-Content "agent-messages.json" -Raw | ConvertFrom-Json
    
    # Tworzę nową wiadomość
    $newMessage = @{
        from = "USER"
        to = $recipients
        priority = "critical"
        subject = $subject
        content = $content
        action = $action
        reference_files = @()
        status = "unread"
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    # Dodaję do listy
    $messages.messages += $newMessage
    
    # Aktualizuję inbox dla każdego odbiorcy
    foreach ($recipient in $recipients) {
        $messages.agent_inboxes.$recipient.unread_count++
        $messages.agent_inboxes.$recipient.inbox += $newMessage.timestamp
    }
    
    # Zapisuję
    $messages | ConvertTo-Json -Depth 10 | Set-Content "agent-messages.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "✅ Wiadomość wysłana!" -ForegroundColor Green
    Write-Host "   Do: $($recipients -join ', ')" -ForegroundColor Cyan
}

function Launch-Agent {
    Write-Host ""
    Write-Host "🚀 URUCHOM AGENTA" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Którego agenta uruchomić?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] Wszystkich"
    $choice = Read-Host "Wybór"
    
    $agents = @()
    if ($choice -eq "1") { $agents = @("alpha") }
    elseif ($choice -eq "2") { $agents = @("beta") }
    elseif ($choice -eq "3") { $agents = @("gamma") }
    elseif ($choice -eq "4") { $agents = @("alpha", "beta", "gamma") }
    
    foreach ($agent in $agents) {
        $scriptPath = Join-Path $RepoPath "agents\$agent\agent-$agent-loop.ps1"
        
        if (Test-Path $scriptPath) {
            Write-Host "   🎯 Uruchamiam agenta $($agent.ToUpper())..." -ForegroundColor Cyan
            
            # Uruchamiam w nowym terminalu PowerShell
            Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$RepoPath'; & '$scriptPath' -GitToken '$env:GITHUB_TOKEN' -RepoPath '$RepoPath'"
            
            Start-Sleep -Seconds 1
        } else {
            Write-Host "   ❌ Skrypt nie znaleziony: $scriptPath" -ForegroundColor Red
        }
    }
    
    Write-Host "✅ Agenci uruchomieni!" -ForegroundColor Green
}

function Show-Status {
    Write-Host ""
    Write-Host "📊 STATUS AGENTÓW" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    cd $RepoPath
    
    $registry = Get-Content "agent-registry.json" -Raw | ConvertFrom-Json
    $messages = Get-Content "agent-messages.json" -Raw | ConvertFrom-Json
    $taskQueue = Get-Content "task-queue.json" -Raw | ConvertFrom-Json
    
    foreach ($agent in $registry.agents) {
        Write-Host "🤖 $($agent.id) - $($agent.name)" -ForegroundColor Cyan
        Write-Host "   Rola: $($agent.role)" -ForegroundColor Gray
        Write-Host "   Status: $($agent.status)" -ForegroundColor Green
        
        $unreadCount = $messages.agent_inboxes.$($agent.id).unread_count
        Write-Host "   Nieprzeczytane wiadomości: $unreadCount" -ForegroundColor Yellow
        
        $prompt = $taskQueue.next_prompt_for.$($agent.id)
        if ($prompt) {
            Write-Host "   Prompt oczekujący: $($prompt.Substring(0, [Math]::Min(50, $prompt.Length)))..." -ForegroundColor Cyan
        }
        Write-Host ""
    }
}

function Open-Folder {
    Write-Host ""
    Write-Host "📂 Otwieramy folder..." -ForegroundColor Cyan
    Start-Process explorer $RepoPath
}

function Sync-GitHub {
    Write-Host ""
    Write-Host "🔄 SYNCHRONIZACJA Z GITHUB" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    cd $RepoPath
    
    git config user.email "control@rojagentow.local" 2>&1 | Out-Null
    git config user.name "Master Control" 2>&1 | Out-Null
    
    Write-Host "📥 Pobieranie..." -ForegroundColor Cyan
    git fetch origin 2>&1 | Out-Null
    
    Write-Host "📤 Wysyłanie..." -ForegroundColor Cyan
    git push origin master --quiet 2>&1 | Out-Null
    
    Write-Host "✅ Zsynchronizowano!" -ForegroundColor Green
}

function Show-Logs {
    Write-Host ""
    Write-Host "🔍 LOGI AGENTÓW" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Którego agenta logi?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] Wszystkich"
    $choice = Read-Host "Wybór"
    
    $agents = @()
    if ($choice -eq "1") { $agents = @("alpha") }
    elseif ($choice -eq "2") { $agents = @("beta") }
    elseif ($choice -eq "3") { $agents = @("gamma") }
    elseif ($choice -eq "4") { $agents = @("alpha", "beta", "gamma") }
    
    foreach ($agent in $agents) {
        $logPath = Join-Path $RepoPath "output\agent-$agent-log.md"
        if (Test-Path $logPath) {
            Write-Host ""
            Write-Host "════════ Agent $($agent.ToUpper()) Log ════════" -ForegroundColor Cyan
            Get-Content $logPath
        }
    }
}

# ════════════════════════════════════════════════════════════
# GŁÓWNA PĘTLA
# ════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "🎯 MASTER CONTROL — Witamy!" -ForegroundColor Yellow
Write-Host ""

while ($true) {
    Show-Menu
    $choice = Read-Host "Wybór"
    
    switch ($choice) {
        "1" { Add-Task }
        "2" { Send-Message }
        "3" { Launch-Agent }
        "4" { Show-Status }
        "5" { Open-Folder }
        "6" { Sync-GitHub }
        "7" { Show-Logs }
        "0" { Write-Host "Wychodzę..."; break }
        default { Write-Host "❌ Nieprawidłowa opcja" -ForegroundColor Red }
    }
}
