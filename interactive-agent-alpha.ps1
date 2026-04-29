# INTERACTIVE AGENT ALPHA - Deep Mathematician
# Real Copilot terminal mode with visible prompt and thinking process
# This agent shows EVERYTHING that Copilot does - not hidden in Python logs

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
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║ AGENT ALPHA - Deep Mathematician - INTERACTIVE COPILOT   ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "[ALPHA] Status: READY" -ForegroundColor Cyan
    Write-Host "[ALPHA] Role: Deep Mathematician - Analyzes complex problems mathematically" -ForegroundColor Cyan
    Write-Host "[ALPHA] Mode: INTERACTIVE (showing real Copilot output)" -ForegroundColor Cyan
    Write-Host "[ALPHA] Polling: Every 5 seconds for new tasks..." -ForegroundColor Cyan
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
    Write-Host "[$timestamp][ALPHA][$Level] $Message" -ForegroundColor $color
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
    git commit -m "[ALPHA] $Message" 2>&1 | Out-Null
    git push 2>&1 | Out-Null
    return $?
}

function Get-NextPrompt {
    # Read task-queue.json and get prompt for ALPHA
    $queueFile = Join-Path $RepoPath "task-queue.json"
    
    if (Test-Path $queueFile) {
        $queue = Get-Content -Raw $queueFile | ConvertFrom-Json
        $prompt = $queue.next_prompt_for.ALPHA
        
        if ($prompt) {
            # Clear the prompt so we don't run it twice
            $queue.next_prompt_for.ALPHA = $null
            $queue | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $queueFile
            return $prompt
        }
    }
    return $null
}

function Send-To-Copilot {
    param($Prompt)
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "📤 SENDING PROMPT TO COPILOT..." -ForegroundColor Blue
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    
    Write-Host ""
    Write-Host "PROMPT:" -ForegroundColor Yellow
    Write-Host $Prompt -ForegroundColor Cyan -BackgroundColor DarkGray
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "[COPILOT THINKING...]" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    
    # Run copilot in INTERACTIVE mode - shows real output
    $output = & copilot -i $Prompt 2>&1 | ForEach-Object {
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
    $outputFile = Join-Path $outputDir "agent-alpha-work.md"
    
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = @"

---
## [$timestamp] ALPHA Analysis
$Content

"@
    
    Add-Content -Path $outputFile -Value $entry
    Log-Message "SUCCESS" "Output saved to agent-alpha-work.md"
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
        from_agent = "ALPHA"
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
    
    # STEP 2: Check for new prompt
    $prompt = Get-NextPrompt
    
    if ($prompt) {
        Log-Message "INFO" ""
        Log-Message "INFO" "╔════════════════════════════════════════╗"
        Log-Message "INFO" "║     🎯 NEW TASK RECEIVED! 🎯        ║"
        Log-Message "INFO" "╚════════════════════════════════════════╝"
        Log-Message "INFO" ""
        
        # STEP 3: Send to Copilot (INTERACTIVE - shows everything!)
        $response = Send-To-Copilot -Prompt $prompt
        
        # STEP 4: Save output
        Save-Output -Content $response
        
        # STEP 5: Send HIGH priority message to BETA
        Send-Message-To-Agent -ToAgent "BETA" `
            -Subject "ALPHA: Mathematical Analysis Complete" `
            -Content $response `
            -Priority "HIGH"
        
        # STEP 6: Commit and push
        if (Git-Commit-Push -Message "Completed mathematical analysis (iteration $iteration)") {
            Log-Message "SUCCESS" "Git commit/push successful"
        } else {
            Log-Message "WARNING" "Git commit/push failed; work saved locally"
        }
        
        Log-Message "SUCCESS" "Task cycle complete!"
        
    } else {
        Log-Message "INFO" "No tasks available - waiting..."
    }
    
    Log-Message "DEBUG" "Sleeping 5 seconds before next poll..."
    Start-Sleep -Seconds 5
}
