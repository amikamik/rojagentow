# 🤖 AUTONOMOUS AGENT ORCHESTRATION SYSTEM

Real Copilot background agents working together autonomously via GitHub.

---

## 🚀 QUICK START

### 1. Launch All Agents (in separate terminals)
```bash
launch-agents.bat
```

This starts three infinite-loop agents:
- **ALPHA** (Deep Mathematician) - Rigorous analysis
- **BETA** (Creative Problem Solver) - Novel approaches  
- **GAMMA** (Visionary Synthesizer) - Holistic integration

### 2. Open Master Control (in a terminal)
```bash
python launch-control.py
```

This opens an interactive menu where you can:
- Add tasks to the queue
- Send CRITICAL messages (urgent commands)
- Send HIGH priority messages (between agents)
- Monitor agent status and logs
- Sync with GitHub
- View task queue

---

## 📊 HOW IT WORKS

### Agent Workflow (5-second loop)

Each agent continuously:

1. **Git Pull** → Fetch latest tasks/messages from GitHub
2. **Priority Check** → Select next work:
   - CRITICAL (user commands) → Drop everything
   - HIGH (from other agents) → Respond immediately
   - NORMAL (task queue) → Regular work
   - MEDIUM (feedback) → Address when possible
3. **Read Context** → Access other agents' output logs
4. **Run Copilot** → Execute `copilot -i "prompt"`
5. **Write Output** → Save results to individual log file
6. **Send Messages** → Notify other agents with HIGH/NORMAL messages
7. **Git Push** → Commit to GitHub
8. **Sleep** → Wait 5 seconds, then loop

### 4-Level Priority Hierarchy

Messages are processed in strict order:

| Priority | Source | Use Case |
|----------|--------|----------|
| **CRITICAL** | USER | Stop everything, execute immediately (e.g., "ALPHA, analyze this NOW") |
| **HIGH** | Agent-to-Agent | Agent B requests Agent A's latest work (e.g., "BETA got analysis from ALPHA, respond to it") |
| **NORMAL** | Task Queue | Regular assignments (e.g., "Solve this problem") |
| **MEDIUM** | Agent Feedback | Suggestions/questions (e.g., "Did you consider X approach?") |

### Inter-Agent Communication

Agents communicate entirely through GitHub files:

- **task-queue.json** - User assigns work via `next_prompt_for[AGENT]`
- **agent-messages.json** - Agents send messages to each other's inboxes
- **output/agent-X-work.md** - Each agent reads the others' output files for context

When BETA wants to build on ALPHA's work:
1. BETA reads its inbox, finds HIGH priority message from ALPHA
2. BETA reads `output/agent-alpha-work.md` to get full context
3. BETA runs copilot with prompt + ALPHA's work as context
4. BETA writes to its own log file
5. BETA sends HIGH message to GAMMA with summary

---

## 📁 PROJECT STRUCTURE

```
rojagentow/
├── config.json                     # Agent roles & settings
├── agent_core.py                   # Shared library (ALL agents use this)
├── 
├── agents/
│   ├── alpha/agent-alpha.py        # ALPHA's autonomous loop
│   ├── beta/agent-beta.py          # BETA's autonomous loop
│   └── gamma/agent-gamma.py        # GAMMA's autonomous loop
├──
├── master_control.py               # User control interface
├── launch-agents.bat               # Start all agents in terminals
├── launch-control.py               # Start Master Control
├──
├── task-queue.json                 # User task assignments
├── agent-messages.json             # Inter-agent message bus
├── agent-registry.json             # Agent metadata (readonly)
├──
└── output/
    ├── agent-alpha-work.md         # ALPHA's work log
    ├── agent-beta-work.md          # BETA's work log
    └── agent-gamma-work.md         # GAMMA's work log
```

---

## 🎮 MASTER CONTROL MENU

When you run `python master_control.py`:

```
[1] Add Task          → Assign work (NORMAL priority, sent to task-queue.json)
[2] CRITICAL Message  → Send urgent USER command (agent stops and obeys)
[3] HIGH Message      → Simulate agent-to-agent communication (HIGH priority)
[4] Launch Agent      → Start an agent in a new terminal
[5] Show Agent Status → See what each agent is working on
[6] Monitor Logs      → View agent output files
[7] Git Sync          → Pull/push to GitHub
[8] Show Task Queue   → View pending work
[0] Exit              → Close Master Control
```

---

## 📝 EXAMPLE WORKFLOW

### Scenario: Solving Riemann Hypothesis

**Step 1: Start Everything**
```bash
launch-agents.bat      # All agents now polling GitHub
```

**Step 2: Give ALPHA a task**
```
Master Control Menu → [1] Add Task
  Task ID: riemann-001
  Title: Analyze Riemann Hypothesis
  Agent: ALPHA
  Prompt: Prove or disprove the Riemann Hypothesis. Show your work.
```

**Step 3: ALPHA works (automatically)**
- ALPHA pulls from GitHub
- Finds "riemann-001" in task-queue.json → next_prompt_for.ALPHA
- Runs: `copilot -i "Prove or disprove..."`
- Writes results to output/agent-alpha-work.md
- Sends HIGH priority message to BETA: "Here's my analysis, check it out"
- Commits to GitHub

**Step 4: BETA responds (automatically)**
- BETA pulls from GitHub
- Finds HIGH priority message from ALPHA
- Reads output/agent-alpha-work.md for context
- Runs: `copilot -i "[ALPHA context] Here's a creative approach..."`
- Writes to output/agent-beta-work.md
- Sends to GAMMA: "I found alternative approach, integrate it"
- Commits to GitHub

**Step 5: GAMMA synthesizes (automatically)**
- GAMMA pulls from GitHub
- Finds HIGH priority message from BETA
- Reads both ALPHA's and BETA's work
- Runs: `copilot -i "[context from both] Here's the complete solution..."`
- Writes to output/agent-gamma-work.md
- Sends updates to both agents
- Commits to GitHub

**Step 6: Monitor progress**
```
Master Control → [6] Monitor Logs
  View all three agents' work in real-time
```

---

## 🔧 CONFIGURATION

Edit `config.json` to customize:

```json
{
  "agents": {
    "ALPHA": {
      "role": "Deep Mathematician",
      "system_prompt": "You are...",
      "output_file": "output/agent-alpha-work.md"
    }
  },
  "github": {
    "owner": "amikamik",
    "repo": "rojagentow",
    "poll_interval_seconds": 5
  }
}
```

---

## 🐛 TROUBLESHOOTING

### Agents won't start?
- Check Python version: `python --version` (should be 3.6+)
- Check Copilot is installed: `copilot --version`
- Check GitHub token is set: `set | grep GITHUB_TOKEN`

### Agents stuck?
- Terminate the terminal window (agents will cleanly stop)
- Re-run `launch-agents.bat`

### Messages not appearing?
- Check `task-queue.json` format (must match schema)
- Check `agent-messages.json` for invalid entries
- Run `git status` to verify files are committed

### Agents not communicating?
- Check `output/agent-X-work.md` exists
- Verify inbox counts: Master Control → [5] Show Agent Status
- Check agent terminal logs for "Message sent to AGENT-X"

---

## 📚 FILES DESCRIPTION

### agent_core.py
Shared library with:
- `git_pull()` - Fetch from GitHub
- `select_next_prompt()` - Priority hierarchy logic
- `run_copilot()` - Execute copilot -i
- `send_message_to_agent()` - Inter-agent messaging
- `read_agent_output()` - Get context from other agents

### agent-alpha.py / agent-beta.py / agent-gamma.py
Each agent:
1. Imports AgentCore
2. Implements infinite while loop
3. Calls agent.select_next_prompt()
4. Runs agent.run_copilot()
5. Calls agent.send_message_to_agent()
6. Calls agent.git_push()
7. Sleeps 5 seconds, repeats

### master_control.py
User interface with functions:
- `add_task_to_queue()` - Add to task-queue.json
- `send_critical_message()` - Create CRITICAL message
- `show_agent_status()` - Display inbox/task status
- `monitor_logs()` - Tail agent output files

---

## 🎯 KEY FEATURES

✅ **Infinite loops** - Agents never stop (unless terminal closed)
✅ **GitHub sync** - All communication via GitHub (git pull/push)
✅ **4-priority system** - CRITICAL > HIGH > NORMAL > MEDIUM
✅ **Inter-agent messaging** - Agents read each other's output
✅ **Real Copilot** - Executes `copilot -i "prompt"` for each task
✅ **Autonomous** - No manual intervention needed (after initial task)
✅ **Colored output** - Easy to distinguish agent streams
✅ **Continuous logging** - All work persisted in output files

---

## 🚦 WHAT'S DIFFERENT FROM MOCK VERSION?

| Feature | Old (Mock) | New (Real) |
|---------|-----------|-----------|
| Agent code | PowerShell loops | Python background processes |
| Copilot | Simulated | Real `copilot -i` execution |
| Communication | Hardcoded | JSON message bus |
| Priorities | Simulated | Actual 4-level hierarchy |
| Logs | Text file | Timestamped Markdown output |
| Control | Single terminal | Separate agent + control terminals |

---

## 📖 NEXT STEPS

1. **Launch agents**: `launch-agents.bat`
2. **Open control**: `python launch-control.py`
3. **Add test task**: Menu → [1] Add Task → Give ALPHA the Riemann task
4. **Monitor logs**: Menu → [6] Monitor Logs → Watch agents work
5. **Send messages**: Experiment with [2] CRITICAL and [3] HIGH messages
6. **Check GitHub**: https://github.com/amikamik/rojagentow (see agent commits)

---

🎯 **Goal**: Fully autonomous multi-agent system that works 24/7 with minimal human intervention.

Good luck! 🚀
