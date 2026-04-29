# Master Control - Agent system controller

param(
    [string]$GitToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = "C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow"
)

$env:GITHUB_TOKEN = $GitToken

function Show-Menu {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor White
    Write-Host "          MASTER CONTROL - AGENT CONTROLLER" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Add task for agent" -ForegroundColor Cyan
    Write-Host "  [2] Send urgent message (CRITICAL)" -ForegroundColor Cyan
    Write-Host "  [3] Launch agent in new window" -ForegroundColor Cyan
    Write-Host "  [4] Show agent status" -ForegroundColor Cyan
    Write-Host "  [5] Open project folder" -ForegroundColor Cyan
    Write-Host "  [6] Sync with GitHub" -ForegroundColor Cyan
    Write-Host "  [7] Show agent logs" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor White
}

function Add-Task {
    Write-Host ""
    Write-Host "ADD NEW TASK" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    $taskId = Read-Host "Task ID (e.g. task-002)"
    $title = Read-Host "Title"
    $description = Read-Host "Description"
    
    Write-Host ""
    Write-Host "For which agent?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] All"
    $agentChoice = Read-Host "Choice"
    
    $agents = @()
    if ($agentChoice -eq "1") { $agents = @("ALPHA") }
    elseif ($agentChoice -eq "2") { $agents = @("BETA") }
    elseif ($agentChoice -eq "3") { $agents = @("GAMMA") }
    elseif ($agentChoice -eq "4") { $agents = @("ALPHA", "BETA", "GAMMA") }
    
    $prompt = Read-Host "Prompt for agent"
    
    cd $RepoPath
    
    try {
        $taskQueue = Get-Content "task-queue.json" -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "ERROR reading task-queue.json: $_" -ForegroundColor Red
        return
    }
    
    $newTask = @{
        id = $taskId
        title = $title
        description = $description
        status = "pending"
        assigned_to = $null
        created_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $taskQueue.tasks += $newTask
    
    foreach ($agent in $agents) {
        $taskQueue.next_prompt_for.$agent = $prompt
    }
    
    $taskQueue | ConvertTo-Json -Depth 10 | Set-Content "task-queue.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "OK! Task added!" -ForegroundColor Green
    Write-Host "   ID: $taskId" -ForegroundColor Cyan
    Write-Host "   Agents: $($agents -join ', ')" -ForegroundColor Cyan
}

function Send-Message {
    Write-Host ""
    Write-Host "SEND URGENT MESSAGE (CRITICAL)" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    $recipient = Read-Host "To whom? (ALPHA/BETA/GAMMA/ALL)"
    if ($recipient -eq "ALL") {
        $recipients = @("ALPHA", "BETA", "GAMMA")
    } else {
        $recipients = @($recipient.ToUpper())
    }
    
    $subject = Read-Host "Subject"
    $content = Read-Host "Content"
    $action = Read-Host "Action (e.g. take task-xyz)"
    
    cd $RepoPath
    
    $messages = Get-Content "agent-messages.json" -Raw | ConvertFrom-Json
    
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
    
    $messages.messages += $newMessage
    
    foreach ($recipient in $recipients) {
        $messages.agent_inboxes.$recipient.unread_count++
        $messages.agent_inboxes.$recipient.inbox += $newMessage.timestamp
    }
    
    $messages | ConvertTo-Json -Depth 10 | Set-Content "agent-messages.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "OK! Message sent!" -ForegroundColor Green
    Write-Host "   To: $($recipients -join ', ')" -ForegroundColor Cyan
}

function Launch-Agent {
    Write-Host ""
    Write-Host "LAUNCH AGENT" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Which agent?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] All"
    $choice = Read-Host "Choice"
    
    $agents = @()
    if ($choice -eq "1") { $agents = @("alpha") }
    elseif ($choice -eq "2") { $agents = @("beta") }
    elseif ($choice -eq "3") { $agents = @("gamma") }
    elseif ($choice -eq "4") { $agents = @("alpha", "beta", "gamma") }
    
    foreach ($agent in $agents) {
        $scriptPath = Join-Path $RepoPath "agents\$agent\agent-$agent-loop.ps1"
        
        if (Test-Path $scriptPath) {
            Write-Host "   Launching agent $($agent.ToUpper())..." -ForegroundColor Cyan
            
            Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$RepoPath'; & '$scriptPath' -GitToken '$env:GITHUB_TOKEN' -RepoPath '$RepoPath'"
            
            Start-Sleep -Seconds 1
        } else {
            Write-Host "   ERROR: Script not found: $scriptPath" -ForegroundColor Red
        }
    }
    
    Write-Host "OK! Agents launched!" -ForegroundColor Green
}

function Show-Status {
    Write-Host ""
    Write-Host "AGENT STATUS" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    cd $RepoPath
    
    $registry = Get-Content "agent-registry.json" -Raw | ConvertFrom-Json
    $messages = Get-Content "agent-messages.json" -Raw | ConvertFrom-Json
    $taskQueue = Get-Content "task-queue.json" -Raw | ConvertFrom-Json
    
    foreach ($agent in $registry.agents) {
        Write-Host "Agent $($agent.id) - $($agent.name)" -ForegroundColor Cyan
        Write-Host "   Role: $($agent.role)" -ForegroundColor Gray
        Write-Host "   Status: $($agent.status)" -ForegroundColor Green
        
        $unreadCount = $messages.agent_inboxes.$($agent.id).unread_count
        Write-Host "   Unread messages: $unreadCount" -ForegroundColor Yellow
        
        $prompt = $taskQueue.next_prompt_for.$($agent.id)
        if ($prompt) {
            $shortPrompt = $prompt.Substring(0, [Math]::Min(50, $prompt.Length))
            Write-Host "   Pending prompt: $shortPrompt..." -ForegroundColor Cyan
        }
        Write-Host ""
    }
}

function Open-Folder {
    Write-Host ""
    Write-Host "Opening folder..." -ForegroundColor Cyan
    Start-Process explorer $RepoPath
}

function Sync-GitHub {
    Write-Host ""
    Write-Host "SYNC WITH GITHUB" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    cd $RepoPath
    
    git config user.email "control@rojagentow.local" 2>&1 | Out-Null
    git config user.name "Master Control" 2>&1 | Out-Null
    
    Write-Host "Fetching..." -ForegroundColor Cyan
    git fetch origin 2>&1 | Out-Null
    
    Write-Host "Pushing..." -ForegroundColor Cyan
    git push origin master --quiet 2>&1 | Out-Null
    
    Write-Host "OK! Synced!" -ForegroundColor Green
}

function Show-Logs {
    Write-Host ""
    Write-Host "AGENT LOGS" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Which agent?" -ForegroundColor Cyan
    Write-Host "  [1] ALPHA"
    Write-Host "  [2] BETA"
    Write-Host "  [3] GAMMA"
    Write-Host "  [4] All"
    $choice = Read-Host "Choice"
    
    $agents = @()
    if ($choice -eq "1") { $agents = @("alpha") }
    elseif ($choice -eq "2") { $agents = @("beta") }
    elseif ($choice -eq "3") { $agents = @("gamma") }
    elseif ($choice -eq "4") { $agents = @("alpha", "beta", "gamma") }
    
    foreach ($agent in $agents) {
        $logPath = Join-Path $RepoPath "output\agent-$agent-log.md"
        if (Test-Path $logPath) {
            Write-Host ""
            Write-Host "======== Agent $($agent.ToUpper()) Log ========" -ForegroundColor Cyan
            Get-Content $logPath
        }
    }
}

Write-Host ""
Write-Host "MASTER CONTROL - Welcome!" -ForegroundColor Yellow
Write-Host ""

while ($true) {
    Show-Menu
    $choice = Read-Host "Choice"
    
    switch ($choice) {
        "1" { Add-Task }
        "2" { Send-Message }
        "3" { Launch-Agent }
        "4" { Show-Status }
        "5" { Open-Folder }
        "6" { Sync-GitHub }
        "7" { Show-Logs }
        "0" { Write-Host "Exiting..."; break }
        default { Write-Host "ERROR: Invalid option" -ForegroundColor Red }
    }
}
