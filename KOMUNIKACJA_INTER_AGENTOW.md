# KOMUNIKACJA MIĘDZY AGENTAMI — ROZSZERZENIE PLANU

## 🎯 PROBLEM

Obecny plan: Agenci tylko czytają task-queue.json. To jednokierunkowe.

**Chcemy:**
- Agent ALPHA: "BETA, skończyłam task-001, sprawdź moje wyniki w output/agent-alpha-log.md"
- BETA odbiera, czyta wynik ALPHA, robi follow-up
- GAMMA może przerwać i powiedzieć: "Czekajcie, ja mam inną ideę — spróbujcie tego"

**Problem z priorytetami:**
- Który prompt ma wartość? Ten z task-queue.json czy wiadomość od kolegi?

---

## ✅ ROZWIĄZANIE: Warstwowe prompty z priorytetami

### Nowa struktura GitHub:

```
rojagentow/
├── task-queue.json              (Główne zadania z User)
├── agent-messages.json          (Wiadomości między agentami)
├── channel.md                   (Historia rozmowy)
├── output/
│   ├── agent-alpha-log.md
│   ├── agent-beta-log.md
│   └── agent-gamma-log.md
└── agents/
    ├── alpha/
    │   ├── agent-alpha-loop.ps1
    │   └── system-prompt.md
    └── ...
```

### Plik: agent-messages.json (NOWY)

```json
{
  "messages": [
    {
      "id": "msg-001",
      "from": "ALPHA",
      "to": ["BETA", "GAMMA"],
      "priority": "high",
      "timestamp": "2026-04-29T20:10:00Z",
      "subject": "Skończyłam task-001, koniec analizy formalno-matematycznej",
      "content": "Zbadałam operatora Hilberta-Pólyi. Wynik: brak naturalnej przestrzeni. Przeczytajcie output/agent-alpha-log.md",
      "action": "BETA, przejdź do task-002 — sprawdzenie luk w Connesie",
      "reference": "task-001",
      "status": "unread"
    },
    {
      "id": "msg-002",
      "from": "USER",
      "to": ["ALPHA"],
      "priority": "critical",
      "timestamp": "2026-04-29T20:15:00Z",
      "subject": "Nowe zadanie: POMIN task-002, przejdź do task-003",
      "content": "Chcę żebyś przeanalizowała podejście geometryczne Langlandsa zamiast sprawdzania Connesa",
      "action": "task-003",
      "status": "unread"
    },
    {
      "id": "msg-003",
      "from": "GAMMA",
      "to": ["ALPHA", "BETA"],
      "priority": "medium",
      "timestamp": "2026-04-29T20:18:00Z",
      "subject": "Pytanie o interpretację geometryczną",
      "content": "Czy zarówno spektralne jak i geometryczne podejście mogą się scalić? Mam ideę, ale potrzebuję Waszych opinii",
      "action": "feedback",
      "status": "unread"
    }
  ],
  
  "next_for_agent": {
    "ALPHA": "msg-002",      ← Priority: msg-002 od USERA
    "BETA": "msg-001",       ← Priority: msg-001 od ALPHA
    "GAMMA": "task-001"      ← Brak msg, czeka na task-queue
  }
}
```

---

## 📊 HIERARCHIA PROMPTÓW (PRIORYTET)

Każdy agent czyta w tej kolejności:

```
1️⃣  KRYTYCZNE (USER OVERRIDE)
    └─ Messages od USER z priority=critical
    └─ Agent: "Kto powiedział STOP? USER! Przerabiam TERAZ"

2️⃣  WYSOKIE (AGENT REQUEST)
    └─ Messages od innych agentów z priority=high
    └─ Agent: "Kolega/Kolezanka mnie wołała, to musi być ważne"

3️⃣  NORMALNE (GŁÓWNE ZADANIA)
    └─ task-queue.json: next_prompt_for[AGENT]
    └─ Agent: "To moje główne zadanie"

4️⃣  MEDIALNE (FEEDBACK)
    └─ Messages z priority=medium
    └─ Agent: "Jak będę miała chwilę, pomyślę nad tym"
```

---

## 🔄 KONKRETNIE — JAK AGENCI SIĘ KOMUNIKUJĄ?

### Scenariusz: ALPHA robi follow-up dla BETA

**T=20:10: ALPHA kończy task-001**

```powershell
# agent-alpha-loop.ps1
...
copilot -i "Zbadaj operator Hilberta..."
# ALPHA pracuje, generuje output

# ALPHA skończyła, uaktualnia:
$result = Get-Content output/agent-alpha-log.md -Tail 100

# ===== KROK 1: Update task-queue =====
$taskQueue | % { if($_.id -eq "task-001") { $_.status = "done" } }
$taskQueue.next_prompt_for.BETA = "task-002"
$taskQueue | ConvertTo-Json | Set-Content task-queue.json

# ===== KROK 2: WYŚLIJ WIADOMOŚĆ BETA =====
$message = @{
    id = "msg-$(Get-Random)"
    from = "ALPHA"
    to = @("BETA", "GAMMA")
    priority = "high"
    timestamp = Get-Date -Format "O"
    subject = "Skończyłam task-001, teraz Twoja kolej BETA"
    content = "Zbadałam operatora Hilberta. Wyniki: brak naturalnej przestrzeni dla H. To otwiera pytanie czy podejście Connesa ma szansę. Przeczytaj: output/agent-alpha-log.md"
    action = "BETA, weź task-002"
    reference = "task-001"
    status = "unread"
}

# Dodaj do agent-messages.json
$messages = Get-Content agent-messages.json | ConvertFrom-Json
$messages.messages += $message
$messages.next_for_agent.BETA = "msg-XXX"  ← BETA będzie czytać tę wiadomość
$messages | ConvertTo-Json | Set-Content agent-messages.json

# ===== KROK 3: COMMIT I PUSH =====
git add agent-messages.json task-queue.json output/agent-alpha-log.md
git commit -m "ALPHA: task-001 done, msg dla BETA i GAMMA"
git push origin main
```

**T=20:12: BETA pole'uje, widzi priorytet**

```powershell
# agent-beta-loop.ps1
git pull

$messages = Get-Content agent-messages.json | ConvertFrom-Json
$taskQueue = Get-Content task-queue.json | ConvertFrom-Json

# SPRAWDZENIE PRIORYTETÓW:
$myMessages = $messages.messages | Where { $_.to -contains "BETA" -and $_.status -eq "unread" }
$myTasks = $taskQueue.next_prompt_for.BETA

if ($myMessages.Count -gt 0) {
    # Mam wiadomość! Czytam ją
    $msg = $myMessages | Sort priority | Select -First 1
    
    $prompt = @"
Oto wiadomość dla Ciebie (priorytet $($msg.priority)):
Od: $($msg.from)
Tytuł: $($msg.subject)
Treść: $($msg.content)
Akcja: $($msg.action)

Przeczytaj wskazane pliki i odpowiedz.
Możesz też wysłać wiadomość zwrotną do $($msg.from).
"@

    copilot -i $prompt
    # BETA pracuje
    
    # Po pracy:
    $msg.status = "read"
    # Update messages.json
} 
elseif ($myTasks) {
    # Brak wiadomości, czytam task-queue
    copilot -i "Weź task: $myTasks..."
}
else {
    # Czekam
    Sleep 5
}
```

---

## 📨 TYPY WIADOMOŚCI MIĘDZY AGENTAMI

### Typ 1: "Skończyłem, teraz Ty"

```json
{
  "from": "ALPHA",
  "to": ["BETA"],
  "priority": "high",
  "subject": "task-001 DONE, pass to BETA",
  "action": "BETA, weź task-002",
  "reference": "task-001"
}
```

### Typ 2: "Czekajcie, przerwę, mam ideę"

```json
{
  "from": "GAMMA",
  "to": ["ALPHA", "BETA"],
  "priority": "high",
  "subject": "Potencjalny przełom — geometria + spektrum",
  "content": "Jeśli połączymy Langlandsa z operatorem H, możemy znaleźć brakujący most kohomologiczny. Czekam na Waszą opinię",
  "action": "feedback",
  "reference": null
}
```

### Typ 3: "Potrzebuję informacji od Ciebie"

```json
{
  "from": "BETA",
  "to": ["ALPHA"],
  "priority": "medium",
  "subject": "Pytanie o interpretację z Twojej analizy",
  "content": "Przeczytałam Twój output. Nie zrozumiałam linii XYZ. Możesz to wyjaśnić?",
  "action": "explain",
  "reference": "output/agent-alpha-log.md"
}
```

### Typ 4: "USER OVERRIDE" (od Ciebie)

```json
{
  "from": "USER",
  "to": ["ALPHA"],
  "priority": "critical",
  "subject": "ZMIANA PLANÓW",
  "content": "Zapomniałem powiedzieć — przeskocz task-002, idź od razu do task-003. Zmieniłem zdanie.",
  "action": "task-003",
  "reference": null
}
```

---

## 🎛️ MASTER CONTROL — ROZSZERZONE OPCJE

```
ROJ AGENTÓW - MASTER CONTROL

[1] Dodaj zadanie do task-queue.json
[2] Dodaj agenta
[3] Wyświetl status
[4] Wyślij wiadomość do agenta
    └─ Jaki agent?
    └─ Treść?
    └─ Priorytet (normal/high/critical)?
[5] Obserwuj komunikację live
    ├─ [5.1] channel.md
    ├─ [5.2] agent-messages.json (nowe)
    ├─ [5.3] task-queue.json
[6] Podgląd output agentów
[q] Wyjdź
```

**Nowa opcja [4]:**

```
> [4] Wyślij wiadomość do agenta
  Który agent: BETA
  Treść: "Sprawdź czy wynik ALPHA o braku przestrzeni H ma sens matematyczny"
  Priorytet [1-critical, 2-high, 3-normal]: 2
  
  → System tworzy msg, dodaje do agent-messages.json, pushuje
  → BETA pole'uje, widzi msg z priority=high, otwiera copilot
```

---

## 🚀 NOWY FLOW — Z KOMUNIKACJĄ

```
T=20:00:
  TY: [1] Dodaj zadanie "Zbadaj Riemanna"
  → task-queue.json: next_prompt_for.ALPHA = "task-001"
  → GitHub PUSH

T=20:01:
  ALPHA pole'uje, widzi: task-001 dla mnie
  → copilot -i "Zbadaj Riemanna..."
  → ALPHA PRACUJE (Terminal 1)

T=20:05:
  BETA, GAMMA pole'ują:
    BETA: next_prompt_for.BETA = null (czeka)
    GAMMA: next_prompt_for.GAMMA = null (czeka)

T=20:10:
  ALPHA skończyła:
    ✓ output/agent-alpha-log.md saved
    ✓ task-queue.json updated: task-001 = done
    ✓ agent-messages.json: dodaj msg do BETA i GAMMA (informacja)
    ✓ GitHub PUSH

T=20:12:
  BETA pole'uje agent-messages.json, widzi msg od ALPHA:
    priority=high, from ALPHA, subject="task-001 DONE"
  → Czyta msg, kopira copilot z kontekstem msg
  → BETA PRACUJE (Terminal 2)

T=20:15:
  GAMMA pole'uje agent-messages.json, widzi msg od ALPHA:
    priority=medium, feedback request
  → GAMMA może pracować nad task-001, lub czekać
  → Jeśli ma opinię, wysyła msg zwrotną do ALPHA

T=20:20:
  BETA skończyła:
    ✓ Wysyła msg do GAMMA: "task-002 DONE, chcę żeby Ty obejrzała geometrię"
    ✓ GAMMA pole'uje, widzi msg od BETA (priority=high)
    ✓ GAMMA PRACUJE (Terminal 3)

T=20:25:
  TY: [4] Wyślij msg do ALPHA:
    "Zmieniam zdanie, przeskocz task-003, idź do task-004"
    priority=critical
  → agent-messages.json: msg od USER dla ALPHA
  → ALPHA pole'uje, widzi priority=critical
  → ALPHA przerywa co robi, czyta msg od USER
  → copilot -i "USER powiedział STOP — weź task-004"
```

---

## 💾 NOWA STRUKTURA: agent-messages.json

```json
{
  "version": "2.0",
  "last_updated": "2026-04-29T20:25:00Z",
  "messages": [
    {
      "id": "msg-001",
      "from": "ALPHA",
      "to": ["BETA", "GAMMA"],
      "priority": "high",
      "timestamp": "2026-04-29T20:10:00Z",
      "subject": "task-001 complete — wyniki do sprawdzenia",
      "content": "Przeanalizowałam operatora Hilberta-Pólyi. Brak naturalnej przestrzeni. Wynik: brak",
      "action": "BETA: weź task-002",
      "reference_files": ["output/agent-alpha-log.md"],
      "reference_task": "task-001",
      "status": "unread",
      "read_by": []
    }
  ],
  
  "agent_inboxes": {
    "ALPHA": {
      "unread_count": 0,
      "last_checked": "2026-04-29T20:24:00Z",
      "inbox": ["msg-005", "msg-007"]
    },
    "BETA": {
      "unread_count": 2,
      "last_checked": "2026-04-29T20:22:00Z",
      "inbox": ["msg-001", "msg-003"]
    },
    "GAMMA": {
      "unread_count": 1,
      "last_checked": "2026-04-29T20:20:00Z",
      "inbox": ["msg-002"]
    }
  },
  
  "next_for_agent": {
    "ALPHA": null,
    "BETA": "msg-001",
    "GAMMA": "task-001"
  }
}
```

---

## ⚙️ ALGORYTM AGENT LOOP — Z PRIORYTETAMI

```powershell
# agent-beta-loop.ps1 — pełna logika

while ($true) {
    # ===== SYNC =====
    git pull origin main --quiet
    
    # ===== CZYTAJ FILES =====
    $messages = Get-Content agent-messages.json | ConvertFrom-Json
    $taskQueue = Get-Content task-queue.json | ConvertFrom-Json
    
    # ===== SZUKAJ MOJEGO NEXT PROMPT =====
    
    # Poziom 1: Czy mam wiadomość od USERA (priority=critical)?
    $criticalMsg = $messages.messages | Where {
        $_.to -contains "BETA" -and 
        $_.priority -eq "critical" -and 
        $_.status -eq "unread"
    } | Sort-Object priority | Select-Object -First 1
    
    if ($criticalMsg) {
        Write-Host "[CRITICAL MESSAGE FROM USER] $($criticalMsg.subject)" -ForegroundColor Red
        $prompt = BuildPromptFromMessage($criticalMsg)
        copilot -i $prompt
        MarkMessageAsRead($criticalMsg.id)
        continue
    }
    
    # Poziom 2: Czy mam HIGH PRIORITY wiadomość od kolegi?
    $highMsg = $messages.messages | Where {
        $_.to -contains "BETA" -and 
        $_.priority -eq "high" -and 
        $_.status -eq "unread"
    } | Sort-Object timestamp | Select-Object -First 1
    
    if ($highMsg) {
        Write-Host "[HIGH MSG FROM $($highMsg.from)] $($highMsg.subject)" -ForegroundColor Yellow
        $prompt = BuildPromptFromMessage($highMsg)
        copilot -i $prompt
        MarkMessageAsRead($highMsg.id)
        continue
    }
    
    # Poziom 3: Czy mam główne zadanie w task-queue?
    $myTask = $taskQueue.next_prompt_for.BETA
    if ($myTask) {
        Write-Host "[TASK] Taking $myTask" -ForegroundColor Green
        $prompt = BuildPromptFromTask($myTask)
        copilot -i $prompt
        UpdateTaskStatus($myTask, "done")
        UpdateNextFor("GAMMA")
        continue
    }
    
    # Poziom 4: Czy mam MEDIUM wiadomości (feedback)?
    $mediumMsg = $messages.messages | Where {
        $_.to -contains "BETA" -and 
        $_.priority -eq "medium" -and 
        $_.status -eq "unread"
    } | Select-Object -First 1
    
    if ($mediumMsg) {
        Write-Host "[MEDIUM MSG] $($mediumMsg.subject)" -ForegroundColor Cyan
        $prompt = BuildPromptFromMessage($mediumMsg)
        copilot -i $prompt
        continue
    }
    
    # Czekaj
    Write-Host "Czekam na nowe zadanie lub wiadomość..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
    
    # ===== PO PRACY: PUSH =====
    git add -A
    git commit -m "BETA: completed work"
    git push origin main --quiet
}
```

---

## ✅ PODSUMOWANIE ZMIAN

| Aspekt | Przed | Teraz |
|--------|-------|-------|
| **Komunikacja** | Jednokierunkowa (task-queue) | Dwukierunkowa (task-queue + agent-messages) |
| **Priorytet** | Wszystko to samo | 4 poziomy: critical > high > normal > medium |
| **Kolaboracja** | Agenci czekają na kolej | Agenci mogą się wołać, dawać feedback |
| **User Override** | Trzeba czekać na koniec | Can interrupt anytime (priority=critical) |
| **Feedback** | Brak | Agenci mogą pytać/sugerować |

---

## 🎯 CZY TO ROZWIĄZUJE Twoje ZASTRZELENIA?

✅ **"Komunikacja między agentami"** — Tak, agent-messages.json  
✅ **"Mówią sobie że skończyli"** — Wiadomość z priority=high  
✅ **"Sprawdzają aktualizacje"** — msg zawiera reference_files  
✅ **"Przekazują sobie działania"** — action field w msg  
✅ **"Priorytet promptów"** — 4-poziomowa hierarchia (critical > high > normal > medium)  
✅ **"Łączenie promptów z głównego pliku + od agentów"** — Algorytm wyżej

Czy to Ci pasuje?

