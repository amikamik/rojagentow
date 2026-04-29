#!/usr/bin/env python3
"""
INTERACTIVE MASTER CONTROL
- View real-time agent conversations
- Submit tasks directly to agents
- Monitor agent reasoning process
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path
from datetime import datetime

# Colors for terminal output
class Colors:
    HEADER = '\033[95m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class InteractiveMaster:
    def __init__(self):
        self.repo_path = Path(__file__).parent
        self.task_queue_file = self.repo_path / "task-queue.json"
        self.messages_file = self.repo_path / "agent-messages.json"
        self.agents = ["ALPHA", "BETA", "GAMMA"]
        
    def clear_screen(self):
        os.system('cls' if os.name == 'nt' else 'clear')
    
    def print_header(self):
        print(f"\n{Colors.BOLD}{Colors.CYAN}")
        print("╔════════════════════════════════════════════════════════════════╗")
        print("║     🤖 INTERACTIVE MULTI-AGENT MASTER CONTROL TERMINAL 🤖     ║")
        print("║                                                                ║")
        print("║  YOU CAN TYPE TASKS HERE AND AGENTS WILL EXECUTE THEM!        ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print(f"{Colors.END}\n")
    
    def show_menu(self):
        print(f"{Colors.BOLD}{Colors.GREEN}")
        print("┌─ WHAT DO YOU WANT TO DO? ─────────────────────────────────────┐")
        print(f"{Colors.END}")
        print(f"{Colors.CYAN}  [1]{Colors.END} Send task to ALPHA (Deep Mathematician)")
        print(f"{Colors.CYAN}  [2]{Colors.END} Send task to BETA (Creative Problem Solver)")
        print(f"{Colors.CYAN}  [3]{Colors.END} Send task to GAMMA (Visionary Synthesizer)")
        print(f"{Colors.CYAN}  [4]{Colors.END} Send task to ALL agents")
        print(f"{Colors.CYAN}  [5]{Colors.END} View agent conversations")
        print(f"{Colors.CYAN}  [6]{Colors.END} View latest agent outputs")
        print(f"{Colors.CYAN}  [7]{Colors.END} Show agent status")
        print(f"{Colors.CYAN}  [0]{Colors.END} Exit")
        print(f"{Colors.BOLD}{Colors.GREEN}")
        print("└────────────────────────────────────────────────────────────────┘")
        print(f"{Colors.END}")
    
    def send_task_to_agent(self, agent_name):
        """Send a task to specific agent"""
        print(f"\n{Colors.BOLD}{Colors.YELLOW}")
        print(f"=== SEND TASK TO {agent_name} ===")
        print(f"{Colors.END}")
        
        task = input(f"What should {agent_name} do? (or 'cancel' to go back): ").strip()
        
        if task.lower() == 'cancel':
            return
        
        if not task:
            print(f"{Colors.RED}❌ Task cannot be empty!{Colors.END}")
            return
        
        try:
            # Read current queue
            if self.task_queue_file.exists():
                with open(self.task_queue_file, 'r') as f:
                    queue = json.load(f)
            else:
                queue = {"next_prompt_for": {}, "tasks": [], "completed_tasks": []}
            
            # Add task to specified agent
            if agent_name == "ALL":
                for agent in self.agents:
                    queue["next_prompt_for"][agent] = task
            else:
                queue["next_prompt_for"][agent_name] = task
            
            # Add to tasks history
            queue["tasks"].append({
                "timestamp": datetime.now().isoformat(),
                "agent": agent_name,
                "task": task
            })
            
            # Write back
            with open(self.task_queue_file, 'w') as f:
                json.dump(queue, f, indent=2)
            
            print(f"\n{Colors.GREEN}✅ TASK SENT!{Colors.END}")
            print(f"{Colors.YELLOW}Task:{Colors.END} {task}")
            print(f"{Colors.YELLOW}To:{Colors.END} {agent_name}")
            print(f"\n{Colors.BOLD}{Colors.CYAN}Agents will pick this up in 5 seconds...{Colors.END}")
            
            # Push to GitHub (optional for local execution, but useful for remote sync)
            print(f"{Colors.CYAN}Pushing to GitHub...{Colors.END}")
            os.chdir(self.repo_path)
            os.system('git add task-queue.json > NUL 2>&1')
            os.system(f'git commit -m "Task for {agent_name}: {task[:50]}" > NUL 2>&1')
            push_code = os.system('git push > NUL 2>&1')
            if push_code == 0:
                print(f"{Colors.GREEN}✓ Pushed to GitHub{Colors.END}\n")
            else:
                print(f"{Colors.YELLOW}⚠ Push blocked, but local agents will still execute this task.{Colors.END}\n")
            
        except Exception as e:
            print(f"{Colors.RED}❌ Error: {e}{Colors.END}\n")
    
    def view_conversations(self):
        """Display agent conversations"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}")
        print("=== AGENT CONVERSATIONS ===")
        print(f"{Colors.END}\n")
        
        try:
            if not self.messages_file.exists():
                print(f"{Colors.YELLOW}No conversations yet...{Colors.END}\n")
                return
            
            with open(self.messages_file, 'r') as f:
                data = json.load(f)
            
            if not data.get("messages"):
                print(f"{Colors.YELLOW}No messages yet...{Colors.END}\n")
                return
            
            # Show last 10 messages
            messages = data["messages"][-10:]
            
            for msg in messages:
                from_agent = msg.get("from_agent", "?")
                to_agent = msg.get("to_agent", "?")
                priority = msg.get("priority", "UNKNOWN").upper()
                subject = msg.get("subject", "")
                content = msg.get("content", "")[:100]
                
                priority_color = {
                    "CRITICAL": Colors.RED,
                    "HIGH": Colors.YELLOW,
                    "NORMAL": Colors.CYAN,
                    "MEDIUM": Colors.GREEN
                }.get(priority, Colors.CYAN)
                
                print(f"{Colors.BOLD}📨 {from_agent} → {to_agent}{Colors.END}")
                print(f"   {priority_color}[{priority}]{Colors.END} {subject}")
                print(f"   {content}...")
                print()
            
        except Exception as e:
            print(f"{Colors.RED}❌ Error: {e}{Colors.END}\n")
    
    def view_outputs(self):
        """Display latest agent outputs"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}")
        print("=== LATEST AGENT OUTPUTS ===")
        print(f"{Colors.END}\n")
        
        output_dir = self.repo_path / "output"
        
        for agent in self.agents:
            output_file = output_dir / f"agent-{agent.lower()}-work.md"
            
            print(f"{Colors.BOLD}{Colors.YELLOW}{agent}:{Colors.END}")
            
            if output_file.exists():
                with open(output_file, 'r') as f:
                    content = f.read()
                
                # Show last 500 chars
                lines = content.split('\n')
                relevant = '\n'.join(lines[-15:])
                print(f"{Colors.GREEN}{relevant}{Colors.END}\n")
            else:
                print(f"{Colors.YELLOW}No output yet{Colors.END}\n")
    
    def show_status(self):
        """Show agent status"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}")
        print("=== AGENT STATUS ===")
        print(f"{Colors.END}\n")
        
        try:
            if self.task_queue_file.exists():
                with open(self.task_queue_file, 'r') as f:
                    queue = json.load(f)
                
                for agent in self.agents:
                    prompt = queue.get("next_prompt_for", {}).get(agent)
                    status = f"{Colors.GREEN}✓ Has task{Colors.END}" if prompt else f"{Colors.YELLOW}⏳ Waiting{Colors.END}"
                    print(f"{Colors.BOLD}{agent}:{Colors.END} {status}")
                    if prompt:
                        print(f"   Task: {prompt[:60]}...")
                    print()
            
        except Exception as e:
            print(f"{Colors.RED}❌ Error: {e}{Colors.END}\n")
    
    def main(self):
        """Main interactive loop"""
        while True:
            try:
                self.clear_screen()
                self.print_header()
                self.show_menu()
                
                choice = input(f"{Colors.BOLD}Your choice (0-7): {Colors.END}").strip()
                
                if choice == '1':
                    self.send_task_to_agent("ALPHA")
                elif choice == '2':
                    self.send_task_to_agent("BETA")
                elif choice == '3':
                    self.send_task_to_agent("GAMMA")
                elif choice == '4':
                    self.send_task_to_agent("ALL")
                elif choice == '5':
                    self.view_conversations()
                    input(f"{Colors.CYAN}Press Enter to continue...{Colors.END}")
                elif choice == '6':
                    self.view_outputs()
                    input(f"{Colors.CYAN}Press Enter to continue...{Colors.END}")
                elif choice == '7':
                    self.show_status()
                    input(f"{Colors.CYAN}Press Enter to continue...{Colors.END}")
                elif choice == '0':
                    print(f"\n{Colors.BOLD}{Colors.GREEN}Goodbye!{Colors.END}\n")
                    break
                else:
                    print(f"{Colors.RED}Invalid choice!{Colors.END}")
                    time.sleep(1)
                    
            except KeyboardInterrupt:
                print(f"\n{Colors.BOLD}{Colors.GREEN}Goodbye!{Colors.END}\n")
                break
            except Exception as e:
                print(f"{Colors.RED}Error: {e}{Colors.END}")
                time.sleep(1)

if __name__ == "__main__":
    master = InteractiveMaster()
    master.main()
