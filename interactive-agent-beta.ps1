# INTERACTIVE AGENT BETA - Creative Problem Solver
# Shows REAL Copilot thinking with streaming output

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = $PSScriptRoot
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ════════════════════════════════════════════════════════════
# TERMINAL HEADER
# ════════════════════════════════════════════════════════════

function Show-Header {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║ AGENT BETA - Creative Problem Solver - INTERACTIVE MODE  ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "[BETA] Status: READY" -ForegroundColor Cyan
    Write-Host "[BETA] Role: Finds creative, novel approaches to problems" -ForegroundColor Cyan
    Write-Host "[BETA] Mode: INTERACTIVE (showing real Copilot output)" -ForegroundColor Cyan
    Write-Host "[BETA] Polling: Every 5 seconds for tasks and messages..." -ForegroundColor Cyan
    Write-Host ""
}

# ════════════════════════════════════════════════════════════
# FUNCTIONS
# ════════════════════════════════════════════════════════════

function Log-Message {
    param($Level, $Message)
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $colors = @{
        "INFO" = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "DEBUG" = "Gray"
    }
    $color = $colors[$Level] ?? "White"
    Write-Host "[$timestamp][BETA][$Level] $Message" -ForegroundColor $color
}

function Git-Pull {
    Log-Message "DEBUG" "Pulling from GitHub..."
    Set-Location $RepoPath
    git pull 2>&1 | Out-Null
    return $?
}

function Git-Commit-Push {
    param($Message)
    Set-Location $RepoPath
    git add . 2>&1 | Out-Null
    git commit -m "[BETA] $Message" 2>&1 | Out-Null
    git push 2>&1 | Out-Null
    return $?
}

function Get-NextPrompt {
    $queueFile = Join-Path $RepoPath "task-queue.json"
    
    if (Test-Path $queueFile) {
        $queue = Get-Content -Raw $queueFile | ConvertFrom-Json
        $prompt = $queue.next_prompt_for.BETA
        
        if ($prompt) {
            $queue.next_prompt_for.BETA = $null
            $queue | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $queueFile
            return $prompt
        }
    }
    return $null
}

function Get-Alpha-Output {
    $alphaFile = Join-Path $RepoPath "output/agent-alpha-work.md"
    if (Test-Path $alphaFile) {
        return Get-Content $alphaFile -Raw
    }
    return $null
}

function Get-High-Priority-Messages {
    $msgFile = Join-Path $RepoPath "agent-messages.json"
    
    if (Test-Path $msgFile) {
        $messages = Get-Content -Raw $msgFile | ConvertFrom-Json
        $inboxProp = $messages.agent_inboxes.PSObject.Properties["BETA"]
        if ($inboxProp -and $inboxProp.Value.messages) {
            return @($inboxProp.Value.messages | Where-Object { $_.priority -eq "HIGH" -and $_.status -eq "unread" })
        }
    }
    return @()
}

function Mark-Message-Read {
    param($MessageId)

    $msgFile = Join-Path $RepoPath "agent-messages.json"
    if (-not (Test-Path $msgFile)) { return }

    $messages = Get-Content -Raw $msgFile | ConvertFrom-Json
    foreach ($m in @($messages.messages)) {
        if ($m.id -eq $MessageId) { $m.status = "read" }
    }

    $inboxProp = $messages.agent_inboxes.PSObject.Properties["BETA"]
    if ($inboxProp) {
        $unread = 0
        foreach ($m in @($inboxProp.Value.messages)) {
            if ($m.id -eq $MessageId) { $m.status = "read" }
            if ($m.status -eq "unread") { $unread++ }
        }
        $inboxProp.Value.unread_count = $unread
    }

    $messages | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $msgFile
}

function Send-To-Copilot {
    param($Prompt, $Context = "")
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "📤 SENDING PROMPT TO COPILOT..." -ForegroundColor Blue
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    
    Write-Host ""
    Write-Host "PROMPT:" -ForegroundColor Yellow
    Write-Host $Prompt -ForegroundColor Cyan -BackgroundColor DarkGray
    
    if ($Context) {
        Write-Host ""
        Write-Host "CONTEXT FROM ALPHA:" -ForegroundColor Yellow
        Write-Host $Context.Substring(0, [Math]::Min(500, $Context.Length)) -ForegroundColor DarkCyan
        Write-Host "..." -ForegroundColor DarkCyan
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "[COPILOT THINKING...]" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    
    # Combine prompt with context
    $fullPrompt = if ($Context) { "$Prompt`n`n---CONTEXT FROM ALPHA:---`n$Context" } else { $Prompt }
    
    # Run Copilot in INTERACTIVE mode
    $output = & copilot -i $fullPrompt 2>&1 | ForEach-Object {
        Write-Host $_ -ForegroundColor White
        $_
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "[COPILOT RESPONSE COMPLETE]" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    
    return ($output | Out-String)
}

function Save-Output {
    param($Content)
    
    $outputDir = Join-Path $RepoPath "output"
    $outputFile = Join-Path $outputDir "agent-beta-work.md"
    
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = @"

---
## [$timestamp] BETA Creative Approach
$Content

"@
    
    Add-Content -Path $outputFile -Value $entry
    Log-Message "SUCCESS" "Output saved to agent-beta-work.md"
}

function Send-Message-To-Agent {
    param($ToAgent, $Subject, $Content, $Priority = "NORMAL")
    
    $msgFile = Join-Path $RepoPath "agent-messages.json"
    
    if (Test-Path $msgFile) {
        $messages = Get-Content -Raw $msgFile | ConvertFrom-Json
    } else {
        $messages = [pscustomobject]@{ messages = @(); agent_inboxes = [pscustomobject]@{} }
    }
    if (-not $messages.messages) {
        $messages | Add-Member -NotePropertyName messages -NotePropertyValue @() -Force
    }
    if (-not $messages.agent_inboxes) {
        $messages | Add-Member -NotePropertyName agent_inboxes -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    
    $message = @{
        id = [guid]::NewGuid().ToString()
        from_agent = "BETA"
        to_agent = $ToAgent
        subject = $Subject
        content = $Content
        priority = $Priority
        status = "unread"
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    }
    
    $messages.messages = @($messages.messages) + @($message)

    $inboxProp = $messages.agent_inboxes.PSObject.Properties[$ToAgent]
    if (-not $inboxProp) {
        $messages.agent_inboxes | Add-Member -NotePropertyName $ToAgent -NotePropertyValue ([pscustomobject]@{ messages = @(); unread_count = 0 }) -Force
    }
    $currentInbox = $messages.agent_inboxes.$ToAgent
    $currentInbox.messages = @($currentInbox.messages) + @($message)
    $currentInbox.unread_count = [int]$currentInbox.unread_count + 1

    $messages | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $msgFile
    
    Log-Message "SUCCESS" "Message sent to $ToAgent ($Priority priority)"
}

# ════════════════════════════════════════════════════════════
# MAIN LOOP
# ════════════════════════════════════════════════════════════

Show-Header

$iteration = 0

while ($true) {
    $iteration++
    
    Log-Message "DEBUG" "═══════════ Iteration $iteration ═══════════"
    
    # STEP 1: Git pull
    if (Git-Pull) {
        Log-Message "SUCCESS" "Git pull successful"
    } else {
        Log-Message "WARNING" "Git pull had issues (might be expected)"
    }
    
    # STEP 2a: Check for direct task
    $prompt = Get-NextPrompt
    $context = ""
    
    if ($prompt) {
        Log-Message "INFO" "NEW TASK RECEIVED!"
    } else {
        # STEP 2b: Check for HIGH priority message from ALPHA
        $highPriorityMsgs = Get-High-Priority-Messages
        
        if ($highPriorityMsgs) {
            Log-Message "INFO" ""
            Log-Message "INFO" "╔════════════════════════════════════════╗"
            Log-Message "INFO" "║  📨 HIGH PRIORITY FROM ALPHA!        ║"
            Log-Message "INFO" "╚════════════════════════════════════════╝"
            
            $msg = $highPriorityMsgs[0]
            Log-Message "INFO" "Subject: $($msg.subject)"
            Mark-Message-Read -MessageId $msg.id
            
            $prompt = "Read and analyze ALPHA's output. Provide a creative approach that complements or challenges ALPHA's analysis."
            $context = Get-Alpha-Output
        }
    }
    
    if ($prompt) {
        # STEP 3: Send to Copilot (INTERACTIVE - shows everything!)
        $response = Send-To-Copilot -Prompt $prompt -Context $context
        
        # STEP 4: Save output
        Save-Output -Content $response
        
        # STEP 5: Send HIGH priority message to GAMMA
        Send-Message-To-Agent -ToAgent "GAMMA" `
            -Subject "BETA: Creative Approach" `
            -Content $response `
            -Priority "HIGH"
        
        # STEP 6: Commit and push
        if (Git-Commit-Push -Message "Creative analysis complete (iteration $iteration)") {
            Log-Message "SUCCESS" "Git commit/push successful"
        } else {
            Log-Message "WARNING" "Git commit/push failed; work saved locally"
        }
        
        Log-Message "SUCCESS" "Task cycle complete!"
        
    } else {
        Log-Message "INFO" "No tasks or high priority messages - waiting..."
    }
    
    Log-Message "DEBUG" "Sleeping 5 seconds before next poll..."
    Start-Sleep -Seconds 5
}
