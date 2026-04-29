#!/usr/bin/env python3
"""
MASTER CONTROL - User interface for controlling agents
Send tasks, monitor status, manage agent fleet
"""

import os
import sys
import json
import time
import subprocess
from datetime import datetime
from pathlib import Path

repo_path = str(Path(__file__).parent)

def load_config():
    """Load configuration"""
    with open(os.path.join(repo_path, "config.json"), 'r') as f:
        return json.load(f)

def load_json_file(filename):
    """Load any JSON file"""
    filepath = os.path.join(repo_path, filename)
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading {filename}: {e}")
        return None

def save_json_file(filename, data):
    """Save JSON file"""
    filepath = os.path.join(repo_path, filename)
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving {filename}: {e}")
        return False

def print_header(title):
    """Print formatted header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60 + "\n")

def print_menu():
    """Print main menu"""
    print_header("MASTER CONTROL - AGENT ORCHESTRATION")
    print("""
    [1] Add Task (to task-queue)
    [2] Send CRITICAL Message (urgent USER command)
    [3] Send HIGH Priority Message (agent-to-agent, urgent)
    [4] Launch Agent in Terminal
    [5] Show Agent Status
    [6] Monitor Agent Logs
    [7] Git Sync Repository
    [8] Show Task Queue
    [0] Exit
    """)

def add_task_to_queue():
    """Add a new task to task queue"""
    print("\n--- ADD TASK ---")
    
    task_id = input("Task ID (e.g., task-001): ").strip()
    task_title = input("Task Title: ").strip()
    task_desc = input("Task Description: ").strip()
    
    print("\nSelect agent(s):")
    print("[1] ALPHA (Mathematician)")
    print("[2] BETA (Creative)")
    print("[3] GAMMA (Synthesizer)")
    print("[4] ALL")
    
    choice = input("Choice: ").strip()
    
    agents = {
        "1": ["ALPHA"],
        "2": ["BETA"],
        "3": ["GAMMA"],
        "4": ["ALPHA", "BETA", "GAMMA"]
    }.get(choice, [])
    
    if not agents:
        print("Invalid choice")
        return
    
    prompt = input(f"Prompt for {','.join(agents)}: ").strip()
    
    if not prompt:
        print("Prompt cannot be empty")
        return
    
    queue = load_json_file("task-queue.json")
    
    new_task = {
        "id": task_id,
        "title": task_title,
        "description": task_desc,
        "agents": agents,
        "prompt": prompt,
        "created_at": datetime.now().isoformat(),
        "status": "pending"
    }
    
    queue["tasks"].append(new_task)
    
    # Set prompt for each agent
    for agent in agents:
        queue["next_prompt_for"][agent] = prompt
    
    if save_json_file("task-queue.json", queue):
        print(f"\n✓ Task '{task_id}' added for {', '.join(agents)}")
        
        # Git push
        try:
            subprocess.run(
                ["git", "add", "task-queue.json"],
                cwd=repo_path,
                capture_output=True
            )
            subprocess.run(
                ["git", "commit", "-m", f"Master: Task {task_id} added"],
                cwd=repo_path,
                capture_output=True
            )
            subprocess.run(
                ["git", "push", "origin", "master"],
                cwd=repo_path,
                capture_output=True
            )
            print("✓ Committed to GitHub")
        except:
            print("⚠ Git commit failed")
    else:
        print("✗ Failed to save task")

def send_critical_message():
    """Send CRITICAL user command"""
    print("\n--- SEND CRITICAL MESSAGE ---")
    
    to_agent = input("To agent (ALPHA/BETA/GAMMA): ").strip().upper()
    
    if to_agent not in ["ALPHA", "BETA", "GAMMA"]:
        print("Invalid agent")
        return
    
    subject = input("Subject: ").strip()
    content = input("Message content: ").strip()
    
    if not content:
        print("Message cannot be empty")
        return
    
    messages = load_json_file("agent-messages.json")
    
    new_message = {
        "id": f"user-critical-{int(time.time())}",
        "from_agent": "USER",
        "to_agent": to_agent,
        "subject": subject,
        "content": content,
        "priority": "critical",
        "status": "unread",
        "timestamp": datetime.now().isoformat()
    }
    
    messages["messages"].append(new_message)
    
    if to_agent not in messages["agent_inboxes"]:
        messages["agent_inboxes"][to_agent] = {"messages": [], "unread_count": 0}
    
    messages["agent_inboxes"][to_agent]["messages"].append(new_message)
    messages["agent_inboxes"][to_agent]["unread_count"] += 1
    
    if save_json_file("agent-messages.json", messages):
        print(f"\n✓ CRITICAL message sent to {to_agent}")
        
        try:
            subprocess.run(["git", "add", "agent-messages.json"], cwd=repo_path, capture_output=True)
            subprocess.run(["git", "commit", "-m", f"Master: CRITICAL message to {to_agent}"], cwd=repo_path, capture_output=True)
            subprocess.run(["git", "push", "origin", "master"], cwd=repo_path, capture_output=True)
            print("✓ Committed to GitHub")
        except:
            pass

def send_high_priority_message():
    """Send HIGH priority message"""
    print("\n--- SEND HIGH PRIORITY MESSAGE ---")
    
    from_agent = input("From (ALPHA/BETA/GAMMA): ").strip().upper()
    to_agent = input("To (ALPHA/BETA/GAMMA): ").strip().upper()
    
    if from_agent not in ["ALPHA", "BETA", "GAMMA"] or to_agent not in ["ALPHA", "BETA", "GAMMA"]:
        print("Invalid agent")
        return
    
    if from_agent == to_agent:
        print("Cannot send to self")
        return
    
    subject = input("Subject: ").strip()
    content = input("Message: ").strip()
    
    if not content:
        return
    
    messages = load_json_file("agent-messages.json")
    
    new_message = {
        "id": f"{from_agent}-to-{to_agent}-{int(time.time())}",
        "from_agent": from_agent,
        "to_agent": to_agent,
        "subject": subject,
        "content": content,
        "priority": "high",
        "status": "unread",
        "timestamp": datetime.now().isoformat()
    }
    
    messages["messages"].append(new_message)
    
    if to_agent not in messages["agent_inboxes"]:
        messages["agent_inboxes"][to_agent] = {"messages": [], "unread_count": 0}
    
    messages["agent_inboxes"][to_agent]["messages"].append(new_message)
    messages["agent_inboxes"][to_agent]["unread_count"] += 1
    
    if save_json_file("agent-messages.json", messages):
        print(f"\n✓ HIGH priority message sent from {from_agent} to {to_agent}")
        
        try:
            subprocess.run(["git", "add", "agent-messages.json"], cwd=repo_path, capture_output=True)
            subprocess.run(["git", "commit", "-m", f"Master: HIGH message {from_agent}→{to_agent}"], cwd=repo_path, capture_output=True)
            subprocess.run(["git", "push", "origin", "master"], cwd=repo_path, capture_output=True)
        except:
            pass

def launch_agent():
    """Launch agent in new terminal"""
    print("\n--- LAUNCH AGENT ---")
    print("[1] ALPHA")
    print("[2] BETA")
    print("[3] GAMMA")
    
    choice = {"1": "ALPHA", "2": "BETA", "3": "GAMMA"}.get(input("Choice: ").strip())
    
    if not choice:
        print("Invalid choice")
        return
    
    agent_dir = os.path.join(repo_path, "agents", choice.lower())
    script = os.path.join(agent_dir, f"agent-{choice.lower()}.py")
    
    if not os.path.exists(script):
        print(f"Script not found: {script}")
        return
    
    try:
        # Launch Python agent in new PowerShell window
        cmd = f'Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd {repo_path}; python {script}"'
        subprocess.Popen(
            ["powershell", "-Command", cmd],
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        print(f"\n✓ {choice} Agent launched in new terminal")
    except Exception as e:
        print(f"✗ Failed to launch agent: {e}")

def show_agent_status():
    """Show current agent status"""
    print_header("AGENT STATUS")
    
    messages = load_json_file("agent-messages.json")
    queue = load_json_file("task-queue.json")
    
    for agent_name in ["ALPHA", "BETA", "GAMMA"]:
        inbox = messages.get("agent_inboxes", {}).get(agent_name, {})
        unread = inbox.get("unread_count", 0)
        has_task = queue["next_prompt_for"].get(agent_name) is not None
        
        status = "IDLE"
        if has_task:
            status = "TASK PENDING"
        if unread > 0:
            status = f"{unread} UNREAD MSG"
        
        output_file = os.path.join(
            repo_path,
            f"output/agent-{agent_name.lower()}-work.md"
        )
        has_output = os.path.exists(output_file)
        
        print(f"[{agent_name}]")
        print(f"  Status: {status}")
        print(f"  Has output: {has_output}")
        if has_task:
            task_prompt = queue["next_prompt_for"][agent_name]
            print(f"  Task: {task_prompt[:60]}...")
        print()

def monitor_logs():
    """Show agent logs"""
    print("\n--- MONITOR LOGS ---")
    print("[1] ALPHA")
    print("[2] BETA")
    print("[3] GAMMA")
    
    choice = {"1": "ALPHA", "2": "BETA", "3": "GAMMA"}.get(input("Choice: ").strip())
    
    if not choice:
        return
    
    log_file = os.path.join(repo_path, f"output/agent-{choice.lower()}-work.md")
    
    if not os.path.exists(log_file):
        print(f"Log file not found: {log_file}")
        return
    
    with open(log_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Show last 50 lines
    print(f"\n--- Last 50 lines of {choice} output ---\n")
    for line in lines[-50:]:
        print(line, end='')

def git_sync():
    """Sync with GitHub"""
    print("\n--- GIT SYNC ---")
    
    try:
        result = subprocess.run(
            ["git", "status"],
            cwd=repo_path,
            capture_output=True,
            text=True
        )
        print(result.stdout)
        
        pull = subprocess.run(
            ["git", "pull", "origin", "master"],
            cwd=repo_path,
            capture_output=True,
            text=True
        )
        print("Pull:", pull.stdout or pull.stderr)
        
        push = subprocess.run(
            ["git", "push", "origin", "master"],
            cwd=repo_path,
            capture_output=True,
            text=True
        )
        print("Push:", push.stdout or push.stderr)
    except Exception as e:
        print(f"Git error: {e}")

def show_task_queue():
    """Display current task queue"""
    print_header("TASK QUEUE")
    
    queue = load_json_file("task-queue.json")
    
    print("Pending Tasks:")
    for task in queue.get("tasks", []):
        if task.get("status") != "completed":
            print(f"\n  ID: {task['id']}")
            print(f"  Title: {task['title']}")
            print(f"  Agents: {', '.join(task['agents'])}")
            print(f"  Prompt: {task['prompt'][:60]}...")
    
    print("\n\nNext Prompts for Agents:")
    for agent in ["ALPHA", "BETA", "GAMMA"]:
        prompt = queue["next_prompt_for"].get(agent)
        if prompt:
            print(f"  {agent}: {prompt[:60]}...")
        else:
            print(f"  {agent}: (none)")

def main():
    """Main control loop"""
    print("\n" + "=" * 60)
    print("  MASTER CONTROL - AUTONOMOUS AGENT ORCHESTRATION")
    print("=" * 60)
    print("\nWelcome! This interface controls your autonomous agent fleet.")
    print("Agents run continuously in their own terminals.\n")
    
    while True:
        print_menu()
        choice = input("Choice: ").strip()
        
        if choice == "1":
            add_task_to_queue()
        elif choice == "2":
            send_critical_message()
        elif choice == "3":
            send_high_priority_message()
        elif choice == "4":
            launch_agent()
        elif choice == "5":
            show_agent_status()
        elif choice == "6":
            monitor_logs()
        elif choice == "7":
            git_sync()
        elif choice == "8":
            show_task_queue()
        elif choice == "0":
            print("\nGoodbye!")
            break
        else:
            print("Invalid choice")
        
        input("\nPress Enter to continue...")

if __name__ == "__main__":
    main()
