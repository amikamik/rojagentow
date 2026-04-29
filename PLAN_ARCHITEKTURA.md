# ROJ AGENTÓW — Plan Architektury Systemu

**Data**: 29.04.2026  
**Status**: 🔵 PLANOWANIE — czeka na akceptację użytkownika  
**Owner**: @amikamik (GitHub)  
**Repo**: github.com/amikamik/rojagentow

---

## 1. PROBLEM PODSTAWOWY

**Wyzwanie**: Agent Copilot jest zaprojektowany do czekania na prompt od użytkownika (`copilot -i "prompt"`), a następnie zakończenia sesji. Potrzebujemy systemu gdzie:
- Agenci działają **automatycznie i ciągle** bez człowieka
- Prompty dostarczane są **wstrzykiwane** przez inne agenty, repozytorium lub pliki zadań
- Praca agentów jest **widoczna na żywo** dla użytkownika
- System jest **sterowany** z głównego terminala bez zatrzymywania agentów

---

## 2. ROZWIĄZANIE OGÓLNE: Architektura GitHub + Worker Loop

### 2.1 Warstwa 1: GitHub jako Centralne Repozytorium

**Struktura repo:**
```
rojagentow/
├── .github/workflows/      (opcjonalnie: CI/CD trigger)
├── agents/
│   ├── alpha/
│   │   ├── system-prompt.md
│   │   ├── state.json
│   │   └── agent-alpha-loop.ps1
│   ├── beta/
│   │   ├── system-prompt.md
│   │   ├── state.json
│   │   └── agent-beta-loop.ps1
│   ├── gamma/
│   │   ├── system-prompt.md
│   │   ├── state.json
│   │   └── agent-gamma-loop.ps1
│   └── [nowy-agent]/
│       ├── system-prompt.md
│       ├── state.json
│       └── agent-*-loop.ps1
├── tasks/
│   └── task-queue.json        ← GŁÓWNY plik zadań (shared by all agents)
├── comms/
│   ├── channel.md             ← Komunikacja między agentami (live)
│   └── agent-registry.json    ← Kto jest w systemie i jaka ma rolę
├── output/
│   ├── agent-alpha-log.md
│   ├── agent-beta-log.md
│   ├── agent-gamma-log.md
│   └── [agent-*-log.md]
└── README.md

```

**GitHub sync**: Każdy agent pull'uje przed pracą, push'uje po zapisie.

---

## 2.2 Warstwa 2: Plik Komunikacyjny — TASKS + COMMS

### Komponenty do rozwiązania:

#### **A) task-queue.json** — Centralna lista zadań

```json
{
  "version": "1.0",
  "timestamp": "2026-04-29T20:30:00Z",
  "tasks": [
    {
      "id": "task-001",
      "title": "Zbadaj hipotezę Riemanna — podejście spektralne",
      "status": "in_progress",
      "assigned_to": "ALPHA",
      "created_at": "2026-04-29T20:00:00Z",
      "started_at": "2026-04-29T20:05:00Z",
      "expected_owner": "BETA",
      "subtasks": [
        {
          "id": "task-001.1",
          "title": "Przeanalizuj operatora Hilberta–Pólyi",
          "status": "done",
          "completed_by": "ALPHA"
        },
        {
          "id": "task-001.2",
          "title": "Zidentyfikuj luki w frameworku Connesa",
          "status": "in_progress",
          "assigned_to": "BETA"
        }
      ]
    }
  ],
  "next_prompt_for": {
    "ALPHA": null,
    "BETA": "task-001.2",
    "GAMMA": null
  }
}
```

**Co to zawiera:**
- Każde zadanie ma ID, status, assignee, ścieżkę zależności
- `next_prompt_for` — wskazuje **jakiemu agentowi wstrzyknąć prompt następny**
- `expected_owner` — sugeruje kto powinien odpowiedzieć (ale nie wymusza)

#### **B) agent-registry.json** — Rejestr agentów

```json
{
  "agents": [
    {
      "id": "ALPHA",
      "role": "Analityk formalno-matematyczny",
      "persona": "Logiczny, ścisły, definiuje pojęcia",
      "status": "active",
      "last_ping": "2026-04-29T20:25:33Z",
      "last_task_completed": "task-001.1",
      "prompt_inject_method": "file",
      "working_dir": "agents/alpha"
    },
    {
      "id": "BETA",
      "role": "Krytyk i badacz luk",
      "persona": "Sceptyczny, szuka nieścisłości, proponuje reformulacje",
      "status": "active",
      "last_ping": "2026-04-29T20:24:55Z",
      "last_task_completed": "task-001.1",
      "prompt_inject_method": "file",
      "working_dir": "agents/beta"
    },
    {
      "id": "GAMMA",
      "role": "Geometra wielowymiarowy",
      "persona": "Topologia, geometria, kategorie, fizyka matematyczna",
      "status": "active",
      "last_ping": "2026-04-29T20:23:12Z",
      "last_task_completed": null,
      "prompt_inject_method": "file",
      "working_dir": "agents/gamma"
    }
  ]
}
```

#### **C) channel.md** — Live komunikacja

Bieżąca rozmowa między agentami (jak dotychczas, ale teraz tracked w GH).

---

## 2.3 Warstwa 3: Worker Loop Pattern (pętla agenta)

Każdy agent ma analogiczną strukturę:

```powershell
# agent-alpha-loop.ps1

while ($true) {
    # 1. PULL z GitHub
    git pull origin main --quiet
    
    # 2. ODCZYTAJ task-queue.json
    $taskQueue = Get-Content tasks/task-queue.json | ConvertFrom-Json
    
    # 3. SPRAWDŹ czy "next_prompt_for.ALPHA" nie jest null
    $myNextTask = $taskQueue.next_prompt_for.ALPHA
    
    if ($myNextTask) {
        # 4. ZNAJDŹ task details
        $task = FindTask $taskQueue $myNextTask
        
        # 5. ZBUDUJ prompt z task info
        $contextFromTask = @"
Masz nowe zadanie do wykonania:
- ID: $($task.id)
- Tytuł: $($task.title)
- Kontekst: [czytaj channel.md dla historii]
Odpowiedź wstrzyknięta automatycznie przez system.
"@
        
        # 6. URUCHOM copilot z wstrzykiętym promptem
        copilot -i $contextFromTask
        
        # 7. ODCZYTAJ wynik z output/agent-alpha-log.md
        $result = Get-Content output/agent-alpha-log.md -Tail 50
        
        # 8. ZAKTUALIZUJ task-queue.json
        # - oznacz task jako done
        # - ustaw next_prompt_for.BETA = task-001.2
        UpdateTaskQueue $taskQueue "ALPHA" "done" "BETA" "task-001.2"
        
        # 9. PUSH do GitHub
        git add -A
        git commit -m "ALPHA: Zakompleted $myNextTask"
        git push origin main
        
        # 10. CZEKAJ (jitter, by uniknąć race condition)
        Start-Sleep -Seconds (Get-Random -Minimum 3 -Maximum 8)
    } else {
        # Brak zadania — poczekaj i sprawdź ponownie
        Start-Sleep -Seconds 5
    }
}
```

**Kluczowe punkty:**
- **Automatyczne prompt injection**: `copilot -i` — prompt zawiera kontekst z task-queue
- **Git ping**: każdy agent pull/push, więc zawsze ma najnowsze dane
- **State tracking**: `next_prompt_for` dzieli zadania bez race condition
- **Jitter**: losowe czekanie między operacjami, by uniknąć simultaneous writes

---

## 2.4 Warstwa 4: Kontrola z Terminala — Sterownia Użytkownika

**Master control terminal** — pozwala użytkownikowi zarządzać bez zatrzymywania agentów:

```powershell
# master-control.ps1

function Add-Task {
    param($title, $assignTo)
    # Edytuj task-queue.json, dodaj zadanie, push
}

function Add-Agent {
    param($agentName, $role, $persona)
    # Stwórz nowy folder agents/$agentName
    # Dodaj do agent-registry.json
    # Uruchom agent-*-loop.ps1 w nowym terminalu
}

function Get-Status {
    # Wyświetl aktualny status všech agentów z GitHub
}

function Inject-Prompt {
    param($agentId, $taskId)
    # Ręcznie ustaw next_prompt_for[$agentId] = $taskId
    # Push
}

# Menu interaktywne
while ($true) {
    Show-Menu
    $choice = Read-Host "Wybierz opcję"
    switch ($choice) {
        "1" { Add-Task }
        "2" { Add-Agent }
        "3" { Get-Status }
        "4" { Inject-Prompt }
        "q" { exit }
    }
}
```

---

## 3. FLOW WYKONANIA — Krok po Kroku

### Scenariusz: Użytkownik dodaje nowe zadanie + dodaje agenta GAMMA

**T=0:00**
- Użytkownik uruchamia `master-control.ps1`
- Wybiera "1. Dodaj zadanie"
- Wpisuje: `"Zbadaj podejście geometryczne Langlandsa"`
- System tworzy task-001.2 w task-queue.json, pushuje

**T=0:05**
- ALPHA poll'uje, widzi że task-queue.json zmienił się
- Czyta `next_prompt_for.ALPHA` — null, czeka
- BETA poll'uje, widzi że jest do roboty
- Copilot otwiera się z kontekstem task-001.2
- BETA pracuje...

**T=0:15**
- BETA skończyła pracę, copilot zamknął sesję
- `output/agent-beta-log.md` zawiera jej analizę
- BETA loop updatuje task-queue.json: task-001.2 → done, `next_prompt_for.ALPHA = task-001.3`
- Pushuje

**T=0:20**
- ALPHA pole'uje, widzi że to jej kolej
- Copilot otwiera się
- ALPHA pracuje...

**T=0:30** — Użytkownik chce dodać agenta
- Wybiera "2. Dodaj agenta"
- Wpisuje: `GAMMA | Geometra wielowymiarowy | [opis]`
- System:
  - Tworzy `agents/gamma/system-prompt.md`
  - Dodaje GAMMA do agent-registry.json
  - Kopiuje `agent-gamma-loop.ps1`
  - Otwiera nowe okno terminala z pętlą GAMMA
  - GAMMA loop startuje, czeka na `next_prompt_for.GAMMA`

---

## 4. ROZWIĄZANIE: CO POWINNO BYĆ W PLIKU KOMUNIKACYJNYM?

### Minimalna struktura task-queue.json:

```json
{
  "task_id": string,
  "title": string,
  "description": string,
  "context_from_channel": string (URL/ref do channel.md),
  "status": "pending|in_progress|done|blocked",
  "assigned_to": string (agent ID),
  "expected_owner_next": string (agent ID — hint kto powinien następny),
  "dependencies": [string],
  "created_by": string,
  "created_at": ISO8601,
  "due_by": ISO8601 (opcjonalnie),
  "metadata": object (agent-specific data)
}
```

### Dodatkowe struktury:

1. **agent-registry.json** — "Kto jest w systemie, jaka ma rolę, czy żyje?"
2. **channel.md** — bieżąca konwersacja (live log)
3. **next_prompt_for**: { ALPHA: null | string, BETA: null | string, ... }

---

## 5. STEROWANIE: Interfejs Master Control Terminal

```
================== ROJ AGENTÓW - MASTER CONTROL ==================

[1] Dodaj nowe zadanie
[2] Dodaj nowego agenta
[3] Wyświetl status wszystkich agentów  
[4] Wstrzyknij prompt do agenta (ręcznie)
[5] Podgląd live: channel.md
[6] Podgląd live: task-queue.json
[7] Podgląd logi agentów
[q] Wyjdź

> _
```

Każdy agent pracuje w **swoim oknie terminala** niezależnie, a master control pozwala dodawać zadania, agentów i obserwować bez przeszkadzania.

---

## 6. WDRAŻANIE — FAZY

### Faza 1: Infrastruktura GitHub
- [ ] Sprawdzić dostęp do GitHub @amikamik
- [ ] Stworzyć repo `rojagentow`
- [ ] Skopiować dane z previous channel.md do output/
- [ ] Zacommitować strukturę folderów

### Faza 2: Worker Loop Framework
- [ ] Stworzyć agent-alpha-loop.ps1 z git sync + task-queue polling
- [ ] Stworzyć agent-beta-loop.ps1 (analogicznie)
- [ ] Stworzyć agent-gamma-loop.ps1 (analogicznie)
- [ ] Przetestować GitHub sync lokalnie

### Faza 3: Master Control + Task Queue
- [ ] Stworzyć task-queue.json (początkowa struktura)
- [ ] Stworzyć agent-registry.json
- [ ] Stworzyć master-control.ps1 (menu interaktywne)

### Faza 4: Live Monitoring
- [ ] Stworzyć live-viewer.ps1 (obserwacja channel.md)
- [ ] Stworzyć agent-status-monitor.ps1 (obserwacja task-queue)

### Faza 5: Testing
- [ ] Uruchomić 3 agentów lokalnie
- [ ] Dodać zadanie, obserwować flow
- [ ] Testować dodawanie nowego agenta mid-run

---

## 7. PYTANIA DO CIEBIE — Akceptacja

Zanim zaczniemy wdrażać, proszę o feedback:

1. **GitHub credentials** — czy mogę poprosić o token PAT dla `@amikamik`?
   
2. **Task Queue — struktura** — czy powyższe JSON schema wystarczy, czy chcesz coś dodać?

3. **Prompt Injection** — czy prompty mają być:
   - Embeddowane w task-queue.json?
   - Oddzielne pliki w `tasks/task-XXX-prompt.md`?
   - Dynamicznie budowane na bazie role agenta + context?

4. **Live Monitoring** — chcesz:
   - Jedno okno terminala z live channel.md (jak przed)?
   - Osobne okno z task-queue status?
   - Jedno unified dashboard?

5. **Output agentów** — gdzie trzymać?
   - `output/agent-*-log.md` (jeden plik na agenta)?
   - `output/runs/YYYY-MM-DD-HHmmss/agent-*-log.md` (po timestampie)?
   - Jako commits w branch per agent?

6. **GitHub Sync Frequency** — jak często agenci mają pull/push?
   - Po każdym zadaniu (current proposal)?
   - Co 30 sekund (continuous)?
   - Na żądanie?

7. **Automatyczne dodawanie agentów** — czy podczas wdrażania chcesz:
   - Wczytać ALPHA, BETA, GAMMA od razu?
   - Zacząć z ALPHA, reszta later?

---

## 8. ZAPROPONOWANE KOLEJNE KROKI

Po Twojej akceptacji:

1. Poproszę dane dostępu do GitHub
2. Stworzyć pełną strukturę repo
3. Wdrożyć Faza 1-3 (infrastruktura + worker loops)
4. Test lokalny
5. Pełne uruchomienie z user control interface

