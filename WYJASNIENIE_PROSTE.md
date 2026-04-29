# ROJ AGENTÓW — WYJAŚNIENIE "JAK DLA DZIECKA"

## 🎯 O CO CHODZI?

Mamy **3 inteligentne roboty** (agenci: ALPHA, BETA, GAMMA), które chcemy aby:
1. Pracowały **niezależnie w swoim terminalu**
2. Mogły się **komunikować między sobą** poprzez plik
3. **Automatycznie brały nowe zadania** bez Twojej pomocy
4. **Ty mogłeś je obserwować** i kontrolować

---

## 📋 JAK DOKŁADNIE TO PRACUJE?

### Przed (dotychczasowy system):

```
TY → manualnie uruchamiasz ALPHA → ALPHA czeka na prompt od CIEBIE
TY → manualnie uruchamiasz BETA → BETA czeka na prompt od CIEBIE
                            ↓
         Musiałeś być całym czas online!
```

### Teraz (nowy system):

```
┌─────────────────────────────────────────────────┐
│  TERMINAL 1: ALPHA              [Terminal]      │
│  Pętla: czytaj → pracuj → zapisz → czekaj      │
│  Niezależnie, bez Twojej pomocy!                │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  TERMINAL 2: BETA               [Terminal]      │
│  Pętla: czytaj → pracuj → zapisz → czekaj      │
│  Niezależnie, bez Twojej pomocy!                │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  TERMINAL 3: GAMMA              [Terminal]      │
│  Pętla: czytaj → pracuj → zapisz → czekaj      │
│  Niezależnie, bez Twojej pomocy!                │
└─────────────────────────────────────────────────┘

         ↓↓↓ WSZYSTKIE RAZEM ↓↓↓

┌─────────────────────────────────────────────────┐
│  GitHub Repo: "rojagentow"                      │
│  - Każdy agent synchronizuje się tutaj          │
│  - Czytają zadania (task-queue.json)            │
│  - Piszą wyniki (logs, output/)                 │
│  - Mogą sobie wysyłać prompty!                  │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  TERMINAL 4: TY (Master Control)                │
│  - Dodajesz nowe zadania                        │
│  - Dodajesz nowych agentów                      │
│  - Obserwujesz co się dzieje                    │
│  - Gdy trzeba — ręcznie wstrzykujesz prompt    │
└─────────────────────────────────────────────────┘
```

---

## 🔄 KONKRETNIE — JAK PRACUJE JEDNA RUNDA?

### Scenariusz: Są już ALPHA, BETA działające

**Czas: 20:00**
```
ALPHA loop:
  ✓ Pulluje z GitHub (czytaj najnowsze dane)
  ✓ Otwiera task-queue.json
  ✓ Szuka: "czy jest dla mnie zadanie w next_prompt_for.ALPHA?"
  ✓ Jest: "task-001" 
  ✓ Uruchamia: copilot -i "Twoje zadanie: task-001 — ... przeczytaj channel.md"
  → ALPHA pracuje (Ty widzisz to w terminalu)
```

**Czas: 20:05**
```
ALPHA skończyła:
  ✓ Saves wynik do output/agent-alpha-log.md
  ✓ Updatuje task-queue.json:
    - task-001: zmień z "in_progress" na "done"
    - next_prompt_for.ALPHA: zmień z "task-001" na null
    - next_prompt_for.BETA: zmień na "task-002" ← BETA teraz jej kolej!
  ✓ Commituje i pushuje do GitHub
  → ALPHA czeka na następne zadanie
```

**Czas: 20:06** (BETA poll'uje co 5 sekund)
```
BETA loop:
  ✓ Pulluje z GitHub (czyta nowe task-queue.json)
  ✓ Szuka: "czy jest dla mnie zadanie?"
  ✓ Jest: next_prompt_for.BETA = "task-002"
  ✓ Uruchamia: copilot -i "Twoje zadanie: task-002 — ... przeczytaj channel.md"
  → BETA pracuje (Ty widzisz to w terminalu)
```

**Czas: 20:10**
```
BETA skończyła:
  ✓ Saves, updatuje, pushuje
  ✓ Ustawia: next_prompt_for.GAMMA = "task-003"
```

**Czas: 20:11**
```
GAMMA loop:
  ✓ Pulluje
  ✓ Widzi: next_prompt_for.GAMMA = "task-003"
  ✓ Uruchamia copilot...
```

**Czas: 20:15** — Ty w Master Control terminalu:
```
> [3] Wyświetl status agentów
  ALPHA: idle (ukończyła task-001)
  BETA: working (task-002, 10% progress)
  GAMMA: working (task-003, 5% progress)
  
> [1] Dodaj nowe zadanie
  Wpisz tytuł: "Zweryfikuj wynik geometrycznego podejścia"
  → System tworzy task-004 i dodaje do GitHub
  → ALPHA pole'uje co 5s, widzi, że task-004 jest dla niej
  → copilot otwiera się automatycznie
```

---

## 🗂️ STRUKTURA GITHUB REPO — UPROSZCZONA

```
rojagentow/
│
├── task-queue.json         ← CENTRALNE. Tutaj są zadania dla każdego agenta
│                             (ALPHA czyta, BETA czyta, GAMMA czyta)
│                             Każdy wie co ma robić
│
├── agent-registry.json     ← "Kto jest w systemie?"
│                             (ALPHA = Analityk, BETA = Krytyk, GAMMA = Geometra)
│
├── channel.md              ← Bieżąca rozmowa (co pisali do siebie)
│
├── output/
│   ├── agent-alpha-log.md  ← Co ALPHA napisała (jej wyniki)
│   ├── agent-beta-log.md   ← Co BETA napisała (jej wyniki)
│   └── agent-gamma-log.md  ← Co GAMMA napisała (jej wyniki)
│
└── agents/
    ├── alpha/
    │   ├── agent-alpha-loop.ps1  ← Program pętli (czytaj → pracuj → pisz)
    │   └── system-prompt.md      ← Kim jest ALPHA? (jej instrukcje)
    ├── beta/
    │   ├── agent-beta-loop.ps1
    │   └── system-prompt.md
    └── gamma/
        ├── agent-gamma-loop.ps1
        └── system-prompt.md
```

**Dlaczego GitHub?**
- Wszystkie agenty mogą tam czytać (pull)
- Wszystkie mogą tam pisać (push)
- To centralne miejsce — jedna źródło prawdy
- Agenci mogą pracować asynchronicznie (jeden czeka, drugi pracuje)

---

## 💾 task-queue.json — CO TO JEST?

Wyobraź sobie **tablicę zadań na lodówce**:

```json
{
  "tasks": [
    {
      "id": "task-001",
      "title": "Przeanalizuj operator Hilberta",
      "status": "done",              ← ALPHA skończyła
      "assigned_to": "ALPHA"
    },
    {
      "id": "task-002",
      "title": "Zweryfikuj lukę w Connesie",
      "status": "in_progress",       ← BETA pracuje TERAZ
      "assigned_to": "BETA"
    },
    {
      "id": "task-003",
      "title": "Rozważ program Langlandsa",
      "status": "pending",           ← Czeka na GAMMA
      "assigned_to": "GAMMA"
    }
  ],
  
  "next_prompt_for": {
    "ALPHA": null,                   ← ALPHA poczeka
    "BETA": "task-002",              ← BETA ma teraz task-002
    "GAMMA": "task-003"              ← GAMMA będzie miała task-003
  }
}
```

**Jak to działa?**
1. ALPHA pole'uje: "co mam robić?" → czyta `next_prompt_for.ALPHA` → null → czeka
2. BETA pole'uje: "co mam robić?" → czyta `next_prompt_for.BETA` → "task-002" → START!
3. GAMMA pole'uje: "co mam robić?" → czyta `next_prompt_for.GAMMA` → "task-003" → START!

---

## 🎛️ MASTER CONTROL — CO TO JEST?

Czwarty terminal — **dla Ciebie**. Menu:

```
Escolhe:
[1] Dodaj nowe zadanie
    → Wpisujesz tytuł → System dodaje do task-queue.json
    → Pushujesz do GitHub
    → Następny agent to widzi i od razu zaczyna

[2] Dodaj nowego agenta
    → Wpisujesz: "DELTA - Fizykę kwantową"
    → System:
      * Tworzy agenti/delta/agent-delta-loop.ps1
      * Dodaje DELTA do agent-registry.json
      * Otwiera NOWY terminal z pętlą DELTA
      * DELTA zaczyna pole'ować i czekać na zadania
    → Bez zatrzymywania ALPHA, BETA, GAMMA!

[3] Wyświetl status
    → ALPHA: idle
    → BETA: working (task-002, 85%)
    → GAMMA: working (task-003, 40%)

[4] Ręcznie prześlij prompt do agenta
    → Np: "ALPHA weź task-005"
    → System update task-queue.json
    → ALPHA pole'uje co 5s, widzi, startuje
```

---

## 🚀 FLOW OD STARTU

```
1. Startujemy system:
   master-control.ps1 ← otwiera się terminal dla Ciebie
   
2. Ty wybierasz [1] Dodaj nowe zadanie:
   → Wpisz: "Zbadaj hipotezę Riemanna"
   → System:
      ✓ Tworzy task-001
      ✓ Ustawia: next_prompt_for.ALPHA = "task-001"
      ✓ Pushuje GitHub
      
3. W tle (w innych terminalach) działają agenci:
   ALPHA loop:
      ✓ Pole'uje, widzi: dla mnie task-001
      ✓ copilot -i "Zbadaj hipotezę Riemanna..."
      → ALPHA pracuje w swoim terminalu
      
   BETA loop:
      ✓ Pole'uje, widzi: next_prompt_for.BETA = null
      ✓ Czeka
      
4. ALPHA skończyła (10 minut później):
   ✓ Saves output/agent-alpha-log.md
   ✓ Update task-queue.json: task-001 = done
   ✓ Ustawia: next_prompt_for.BETA = "task-002"
   ✓ Pushuje GitHub
   
5. BETA pole'uje, widzi: teraz ja!
   ✓ copilot -i "Sprawdź wynik ALPHA..."
   → BETA pracuje
   
6. Ty (w Master Control) widzisz na żywo:
   - channel.md (co pisali do siebie)
   - task-queue.json (kto co robił)
   - Logi: output/agent-*.md
```

---

## ❓ PYTANIA — WYJAŚNIENIE

### Q1: "Gdzie przechowywać prompty agent\u00f3w?"

**Opcja A: W task-queue.json**
```json
{
  "id": "task-001",
  "title": "...",
  "prompt": "Jesteś ALPHA. Zrób to i to. Przeczytaj channel.md..."
}
```
👍 Wszystko w jednym miejscu  
👎 task-queue.json robi się wielki

**Opcja B: Oddzielne pliki**
```
tasks/
  ├── task-001-prompt.md
  ├── task-002-prompt.md
```
Agent czyta: `Get-Content tasks/task-XXX-prompt.md`  
👍 Prompty mogą być bardzo długie  
👎 Więcej plików

**Opcja C: Dynamicznie (POLECENIE)**
```powershell
# Agent wie: jestem ALPHA, moja rola to "Analityk"
# Agent wie: zadanie to task-001
# Agent zbuduje prompt:
$prompt = @"
Jesteś ALPHA - Analityk matematyczny.
Masz zadanie: $(task.title)
Kontekst z channel.md pokazuje: [czytaj channel.md]
Rób to precyzyjnie.
"@
```
👍 Proste, bez dodatkowych plików  
👎 Wymaga logiki w pętli

**Co polecam?** → **Opcja C** (dynamicznie z roli + zadania)

---

### Q2: "Jak cz\u0119sto agenci mają pull/push do GitHub?"

**Opcja A: Po każdym zadaniu**
```
Agent pracuje → Skończył → Save → Push GitHub → Czeka
Następny agent → Pull → Widzi → Pracuje
```
👍 Synchronnie, jasno kto robi co  
👍 Mniej konfliktów  
👎 Jeśli GitHub jest wolny, czeka się dłużej

**Opcja B: Co 30 sekund**
```
Agent pracuje → co 30s commituje co porobi
```
👍 Ciągła synchronizacja  
👎 Chaos — agent może nie wiedzieć czy kolega skończył

**Opcja C: Na sygnał (Ty kontrolujesz)**
```
Agent pracuje → Ty naciśniesz [5] Sync teraz → Push
```
👍 Masz kontrolę  
👎 Trzeba pamiętać

**Co polecam?** → **Opcja A** (po każdym zadaniu) — najjasniejsza

---

### Q3: "Gdzie przechowywać output agent\u00f3w?"

**Opcja A: Jeden plik na agenta**
```
output/
  ├── agent-alpha-log.md      (zawsze ostatni wynik ALPHy)
  ├── agent-beta-log.md       (zawsze ostatni wynik BETy)
  └── agent-gamma-log.md
```
👍 Proste, łatwo znaleźć  
👎 Historia znika (overwrite)

**Opcja B: Timestamped runs**
```
output/
  ├── 2026-04-29-200505_alpha_task-001.md
  ├── 2026-04-29-200510_beta_task-001.md
  └── 2026-04-29-200515_gamma_task-002.md
```
👍 Pełna historia  
👎 Dużo plików

**Opcja C: Per-agent branches** (zaawansowane)
```
GitHub:
  main ← ostateczne wyniki
  ├── branch: agent/alpha
  ├── branch: agent/beta
  └── branch: agent/gamma
```
👍 Git history za darmo  
👎 Skomplikowane dla początkujących

**Co polecam?** → **Opcja B** (timestamped) — zachowujesz historię, widzisz progres

---

### Q4: "Ilu agentów startować?"

**Opcja A: Wszystkich od razu (ALPHA, BETA, GAMMA)**
👍 System gotowy do pracy  
👎 Jeśli coś spadnie, wszystko pada

**Opcja B: ALPHA do testu**
👍 Testujemy z jednym agentem  
👎 Długo trwa

**Opcja C: ALPHA → BETA → GAMMA etapowo** (POLECENIE)
👍 Testujemy po drodze  
👍 Gdy jeden działa, dodajemy następnego  
👎 Wymaga czekania

**Co polecam?** → **Opcja C** — ALPHA na start, potem BETA, potem GAMMA. Testy w trakcie.

---

## 📊 PODSUMOWANIE — WIZUALIZACJA

```
┌───────────────────────────────────────────────────────────────┐
│  TY (Master Control)                                          │
│  └─ [1] Dodaj zadanie → task-queue.json                      │
│  └─ [2] Dodaj agenta → agent-registry.json + nowy terminal   │
│  └─ [3] Wyświetl status                                       │
│  └─ [4] Ręczny prompt                                         │
└───────────────────────────────────────────────────────────────┘
          ↓↓↓ PUSH GitHub ↓↓↓
┌────────────────────────────┐
│   GITHUB REPO: rojagentow  │
│   ├─ task-queue.json       │
│   ├─ agent-registry.json   │
│   ├─ channel.md            │
│   └─ output/*.md           │
└────────────────────────────┘
  ↑↑↑ PULL GitHub ↑↑↑
  
  ALPHA            BETA            GAMMA
┌────────────┐  ┌────────────┐  ┌────────────┐
│ Terminal 1 │  │ Terminal 2 │  │ Terminal 3 │
│ Loop:      │  │ Loop:      │  │ Loop:      │
│ • Pull     │  │ • Pull     │  │ • Pull     │
│ • Czytaj   │  │ • Czytaj   │  │ • Czytaj   │
│ • Pracuj   │  │ • Pracuj   │  │ • Pracuj   │
│ • Pisz     │  │ • Pisz     │  │ • Pisz     │
│ • Push     │  │ • Push     │  │ • Push     │
│ • Czekaj   │  │ • Czekaj   │  │ • Czekaj   │
└────────────┘  └────────────┘  └────────────┘
```

---

## ✅ GOTOWY?

Jeśli plan jasny — mogę zacząć wdrażać Fazę 1-2:

1. **Faza 1**: Struktura GitHub repo
2. **Faza 2**: Pętla ALPHA (agent-alpha-loop.ps1 z git sync)
3. **Test**: Czy ALPHA się startuje i synchronizuje?
4. **Faza 3**: Pętla BETA, GAMMA
5. **Faza 4**: Master Control terminal

Czy chcesz żebym zacząć?

