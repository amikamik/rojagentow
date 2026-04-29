# INTERACTIVE AGENT GAMMA - Visionary Synthesizer
# ASCII-safe version to avoid parser issues in Windows PowerShell.

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$RepoPath = $PSScriptRoot
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Show-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "AGENT GAMMA - Visionary Synthesizer - INTERACTIVE MODE" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "[GAMMA] Status: READY" -ForegroundColor Cyan
    Write-Host "[GAMMA] Role: Synthesizes ALPHA and BETA perspectives" -ForegroundColor Cyan
    Write-Host "[GAMMA] Mode: Interactive Copilot output streaming" -ForegroundColor Cyan
    Write-Host "[GAMMA] Polling: Every 5 seconds for messages from ALPHA and BETA" -ForegroundColor Cyan
    Write-Host ""
}

function Log-Message {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $color = "White"
    switch ($Level) {
        "INFO" { $color = "Cyan" }
        "SUCCESS" { $color = "Green" }
        "WARNING" { $color = "Yellow" }
        "ERROR" { $color = "Red" }
        "DEBUG" { $color = "Gray" }
    }
    Write-Host "[$timestamp][GAMMA][$Level] $Message" -ForegroundColor $color
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json)
    } catch {
        Log-Message "WARNING" "Invalid JSON in $Path"
        return $null
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )
    $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
}

function Git-Pull {
    Set-Location $RepoPath
    git pull 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Git-Commit-Push {
    param([string]$Message)
    Set-Location $RepoPath
    git add . 2>&1 | Out-Null
    git commit -m "[GAMMA] $Message" 2>&1 | Out-Null
    git push 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-Alpha-Output {
    $path = Join-Path $RepoPath "output\agent-alpha-work.md"
    if (Test-Path $path) { return (Get-Content -Raw -Encoding UTF8 $path) }
    return ""
}

function Get-Beta-Output {
    $path = Join-Path $RepoPath "output\agent-beta-work.md"
    if (Test-Path $path) { return (Get-Content -Raw -Encoding UTF8 $path) }
    return ""
}

function Get-NextPrompt {
    $queueFile = Join-Path $RepoPath "task-queue.json"
    $queue = Read-JsonFile -Path $queueFile
    if (-not $queue -or -not $queue.next_prompt_for) { return $null }

    $prompt = $queue.next_prompt_for.GAMMA
    if ($prompt) {
        $queue.next_prompt_for.GAMMA = $null
        Write-JsonFile -Path $queueFile -Value $queue
        return $prompt
    }
    return $null
}

function Get-High-Priority-Messages {
    $msgFile = Join-Path $RepoPath "agent-messages.json"
    $messages = Read-JsonFile -Path $msgFile
    if (-not $messages -or -not $messages.agent_inboxes) { return @() }

    $inboxProp = $messages.agent_inboxes.PSObject.Properties["GAMMA"]
    if (-not $inboxProp -or -not $inboxProp.Value.messages) { return @() }

    return @($inboxProp.Value.messages | Where-Object { $_.priority -eq "HIGH" -and $_.status -eq "unread" })
}

function Mark-Message-Read {
    param([string]$MessageId)

    $msgFile = Join-Path $RepoPath "agent-messages.json"
    $messages = Read-JsonFile -Path $msgFile
    if (-not $messages) { return }

    foreach ($m in @($messages.messages)) {
        if ($m.id -eq $MessageId) { $m.status = "read" }
    }

    $inboxProp = $messages.agent_inboxes.PSObject.Properties["GAMMA"]
    if ($inboxProp) {
        $unread = 0
        foreach ($m in @($inboxProp.Value.messages)) {
            if ($m.id -eq $MessageId) { $m.status = "read" }
            if ($m.status -eq "unread") { $unread++ }
        }
        $inboxProp.Value.unread_count = $unread
    }

    Write-JsonFile -Path $msgFile -Value $messages
}

function Send-To-Copilot {
    param(
        [string]$Prompt,
        [string]$AlphaContext,
        [string]$BetaContext
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Blue
    Write-Host "SENDING PROMPT TO COPILOT" -ForegroundColor Blue
    Write-Host "============================================================" -ForegroundColor Blue
    Write-Host "PROMPT:" -ForegroundColor Yellow
    Write-Host $Prompt -ForegroundColor Cyan

    if ($AlphaContext) {
        Write-Host ""
        Write-Host "ALPHA CONTEXT (preview):" -ForegroundColor Yellow
        Write-Host $AlphaContext.Substring(0, [Math]::Min(300, $AlphaContext.Length)) -ForegroundColor DarkCyan
        Write-Host "..."
    }
    if ($BetaContext) {
        Write-Host ""
        Write-Host "BETA CONTEXT (preview):" -ForegroundColor Yellow
        Write-Host $BetaContext.Substring(0, [Math]::Min(300, $BetaContext.Length)) -ForegroundColor DarkCyan
        Write-Host "..."
    }

    $fullPrompt = $Prompt
    if ($AlphaContext) { $fullPrompt += "`n`n---ALPHA ANALYSIS---`n$AlphaContext" }
    if ($BetaContext) { $fullPrompt += "`n`n---BETA ANALYSIS---`n$BetaContext" }

    Write-Host ""
    Write-Host "[COPILOT OUTPUT]" -ForegroundColor Magenta
    Write-Host ""

    $output = & copilot -i $fullPrompt 2>&1 | ForEach-Object {
        Write-Host $_ -ForegroundColor White
        $_
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "[COPILOT WARNING] copilot exited with code $exitCode" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "[COPILOT RESPONSE COMPLETE]" -ForegroundColor Green
    return ($output | Out-String)
}

function Save-Output {
    param([string]$Content)

    $outputDir = Join-Path $RepoPath "output"
    $outputFile = Join-Path $outputDir "agent-gamma-work.md"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "`n---`n## [$timestamp] GAMMA Synthesis`n$Content`n"
    Add-Content -Path $outputFile -Value $entry -Encoding UTF8
    Log-Message "SUCCESS" "Output saved to agent-gamma-work.md"
}

function Send-Message-To-Agent {
    param(
        [string]$ToAgent,
        [string]$Subject,
        [string]$Content,
        [string]$Priority = "NORMAL"
    )

    $msgFile = Join-Path $RepoPath "agent-messages.json"
    $messages = Read-JsonFile -Path $msgFile
    if (-not $messages) {
        $messages = [pscustomobject]@{
            messages = @()
            agent_inboxes = [pscustomobject]@{}
        }
    }
    if (-not $messages.messages) {
        $messages | Add-Member -NotePropertyName messages -NotePropertyValue @() -Force
    }
    if (-not $messages.agent_inboxes) {
        $messages | Add-Member -NotePropertyName agent_inboxes -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $message = [pscustomobject]@{
        id = [guid]::NewGuid().ToString()
        from_agent = "GAMMA"
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
        $messages.agent_inboxes | Add-Member -NotePropertyName $ToAgent -NotePropertyValue ([pscustomobject]@{
            messages = @()
            unread_count = 0
        }) -Force
    }

    $currentInbox = $messages.agent_inboxes.$ToAgent
    $currentInbox.messages = @($currentInbox.messages) + @($message)
    $currentInbox.unread_count = [int]$currentInbox.unread_count + 1

    Write-JsonFile -Path $msgFile -Value $messages
    Log-Message "SUCCESS" "Message sent to $ToAgent ($Priority)"
}

Show-Header
$iteration = 0

while ($true) {
    $iteration++
    Log-Message "DEBUG" "Iteration $iteration"

    if (Git-Pull) {
        Log-Message "SUCCESS" "Git pull successful"
    } else {
        Log-Message "WARNING" "Git pull failed"
    }

    $directPrompt = Get-NextPrompt
    $highPriorityMsgs = Get-High-Priority-Messages

    if ($directPrompt) {
        Log-Message "INFO" "DIRECT TASK RECEIVED for GAMMA"
        $response = Send-To-Copilot -Prompt $directPrompt -AlphaContext "" -BetaContext ""
        Save-Output -Content $response
        if (Git-Commit-Push -Message "Direct task complete (iteration $iteration)") {
            Log-Message "SUCCESS" "Git commit/push successful"
        } else {
            Log-Message "WARNING" "Git commit/push failed; work saved locally"
        }
    } elseif ($highPriorityMsgs.Count -gt 0) {
        $msg = $highPriorityMsgs[0]
        Log-Message "INFO" "HIGH message from BETA: $($msg.subject)"
        Mark-Message-Read -MessageId $msg.id

        $prompt = "Review ALPHA and BETA analyses, then synthesize one integrated final answer."
        $alphaOutput = Get-Alpha-Output
        $betaOutput = Get-Beta-Output

        $response = Send-To-Copilot -Prompt $prompt -AlphaContext $alphaOutput -BetaContext $betaOutput
        Save-Output -Content $response

        Send-Message-To-Agent -ToAgent "ALPHA" -Subject "GAMMA: Integrated Synthesis" -Content "GAMMA completed synthesis. See output/agent-gamma-work.md" -Priority "NORMAL"
        Send-Message-To-Agent -ToAgent "BETA" -Subject "GAMMA: Integrated Synthesis" -Content "GAMMA completed synthesis. See output/agent-gamma-work.md" -Priority "NORMAL"

        if (Git-Commit-Push -Message "Synthesis complete (iteration $iteration)") {
            Log-Message "SUCCESS" "Git commit/push successful"
        } else {
            Log-Message "WARNING" "Git commit/push failed; work saved locally"
        }
    } else {
        Log-Message "INFO" "No direct task and no high priority messages"
    }

    Log-Message "DEBUG" "Sleeping 5 seconds before next poll..."
    Start-Sleep -Seconds 5
}
