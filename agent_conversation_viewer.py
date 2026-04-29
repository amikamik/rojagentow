#!/usr/bin/env python3
"""
AGENT CONVERSATION VIEWER - Real-time dashboard showing agent conversations
Shows what agents are saying to each other in human-readable format
"""

import os
import json
import time
import sys
from datetime import datetime
from pathlib import Path
from collections import OrderedDict

repo_path = str(Path(__file__).parent)

def clear_screen():
    """Clear terminal screen"""
    os.system('cls' if os.name == 'nt' else 'clear')

def load_messages():
    """Load all messages and work files"""
    messages_path = os.path.join(repo_path, "agent-messages.json")
    with open(messages_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def load_work_files():
    """Load all agent work outputs"""
    work = {}
    for agent in ["ALPHA", "BETA", "GAMMA"]:
        file_path = os.path.join(repo_path, f"output/agent-{agent.lower()}-work.md")
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Get last section
                sections = content.split("============================================================")
                if len(sections) > 1:
                    work[agent] = sections[-1].strip()
        else:
            work[agent] = None
    return work

def get_agent_role(agent_name):
    """Get agent role"""
    roles = {
        "ALPHA": "🔵 Deep Mathematician",
        "BETA": "🟢 Creative Problem Solver",
        "GAMMA": "🟡 Visionary Synthesizer"
    }
    return roles.get(agent_name, agent_name)

def print_header():
    """Print dashboard header"""
    print("\033[2J\033[H")  # Clear screen
    print("╔════════════════════════════════════════════════════════════════════╗")
    print("║         🤖 AUTONOMOUS AGENTS - REAL-TIME CONVERSATION VIEW 🤖     ║")
    print("╚════════════════════════════════════════════════════════════════════╝")
    print("")

def print_agents_overview():
    """Print current agent status"""
    print("📊 AGENT STATUS:")
    print("─" * 70)
    
    agents = {
        "ALPHA": "🔵 Deep Mathematician - Rigorous analysis",
        "BETA": "🟢 Creative Problem Solver - Novel approaches",
        "GAMMA": "🟡 Visionary Synthesizer - Holistic integration"
    }
    
    for agent, desc in agents.items():
        print(f"  {desc}")
    
    print("")

def print_messages_section():
    """Print inter-agent messages and conversations"""
    print("💬 AGENT CONVERSATIONS:")
    print("─" * 70)
    
    messages = load_messages()
    all_messages = messages.get("messages", [])
    
    if not all_messages:
        print("  (No messages yet - agents waiting for tasks)")
        print("")
        return
    
    # Group by conversation
    conversations = {}
    for msg in all_messages:
        key = tuple(sorted([msg["from_agent"], msg["to_agent"]]))
        if key not in conversations:
            conversations[key] = []
        conversations[key].append(msg)
    
    # Sort by timestamp and display
    all_messages_sorted = sorted(all_messages, key=lambda x: x.get("timestamp", ""), reverse=True)
    
    # Show most recent messages first (last 10)
    for msg in all_messages_sorted[:10]:
        from_agent = msg.get("from_agent", "?")
        to_agent = msg.get("to_agent", "?")
        subject = msg.get("subject", "")
        priority = msg.get("priority", "").upper()
        status = "✓" if msg.get("status") == "read" else "●"
        
        # Color by priority
        priority_colors = {
            "CRITICAL": "\033[91m",  # Red
            "HIGH": "\033[92m",      # Green
            "NORMAL": "\033[93m",    # Yellow
            "MEDIUM": "\033[94m"     # Blue
        }
        color = priority_colors.get(priority, "")
        reset = "\033[0m"
        
        print(f"  {status} [{color}{priority}{reset}] {from_agent} → {to_agent}")
        print(f"      Subject: {subject}")
        
        # Show preview of content
        content = msg.get("content", "")
        if len(content) > 60:
            print(f"      Message: {content[:60]}...")
        else:
            print(f"      Message: {content}")
        print("")

def print_agent_work():
    """Print what agents have produced"""
    print("📝 AGENT WORK OUTPUT:")
    print("─" * 70)
    
    work = load_work_files()
    
    for agent in ["ALPHA", "BETA", "GAMMA"]:
        if work.get(agent):
            print(f"\n  {get_agent_role(agent)}:")
            print(f"  {'-' * 50}")
            
            # Get last 300 chars
            output = work[agent]
            if len(output) > 300:
                print(f"  ...{output[-300:]}")
            else:
                print(f"  {output}")
        else:
            print(f"\n  {get_agent_role(agent)}: (no output yet)")

def print_task_queue():
    """Show current tasks"""
    print("\n📋 TASK QUEUE:")
    print("─" * 70)
    
    queue_path = os.path.join(repo_path, "task-queue.json")
    with open(queue_path, 'r', encoding='utf-8') as f:
        queue = json.load(f)
    
    next_prompts = queue.get("next_prompt_for", {})
    
    has_tasks = False
    for agent in ["ALPHA", "BETA", "GAMMA"]:
        prompt = next_prompts.get(agent)
        if prompt:
            print(f"  ⏳ {agent}: {prompt[:60]}")
            if len(prompt) > 60:
                print(f"           {prompt[60:120]}")
            has_tasks = True
    
    if not has_tasks:
        print("  (No pending tasks)")
    
    print("")

def print_conversation_flow():
    """Show conversation flow diagram"""
    print("\n🔄 CONVERSATION FLOW:")
    print("─" * 70)
    
    messages = load_messages()
    all_messages = sorted(messages.get("messages", []), key=lambda x: x.get("timestamp", ""))
    
    if not all_messages:
        print("  (Waiting for first message...)")
        return
    
    # Build timeline
    print("")
    timeline = []
    for msg in all_messages[-5:]:  # Last 5 messages
        from_agent = msg.get("from_agent", "?")
        to_agent = msg.get("to_agent", "?")
        priority = msg.get("priority", "").upper()
        
        timeline.append(f"  {from_agent} --[{priority}]--> {to_agent}")
    
    for line in timeline:
        print(line)
    
    print("")

def print_footer():
    """Print footer"""
    print("─" * 70)
    print(f"  Last updated: {datetime.now().strftime('%H:%M:%S')}")
    print("  Press Ctrl+C to exit")
    print("")

def main():
    """Main loop"""
    print("Starting Agent Conversation Viewer...")
    print("Loading data...")
    time.sleep(1)
    
    try:
        while True:
            print_header()
            print_agents_overview()
            print_messages_section()
            print_agent_work()
            print_task_queue()
            print_conversation_flow()
            print_footer()
            
            # Refresh every 3 seconds
            time.sleep(3)
            
    except KeyboardInterrupt:
        print("\n✓ Viewer stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()
