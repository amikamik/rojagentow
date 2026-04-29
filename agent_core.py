#!/usr/bin/env python3
"""
AGENT CORE - Shared logic for all autonomous background agents
Real Copilot integration for multi-agent orchestration system
"""

import os
import json
import subprocess
import time
from datetime import datetime
from pathlib import Path
import sys
import threading

class AgentCore:
    def __init__(self, agent_name, repo_path=None):
        """Initialize an agent with name and repository path"""
        self.agent_name = agent_name
        self.repo_path = repo_path or os.getcwd()
        self.config = self._load_config()
        self.agent_config = self.config["agents"].get(agent_name)
        
        if not self.agent_config:
            raise ValueError(f"Agent {agent_name} not found in config")
        
        self.output_file = os.path.join(self.repo_path, self.agent_config["output_file"])
        os.makedirs(os.path.dirname(self.output_file), exist_ok=True)
        
    def _load_config(self):
        """Load config.json"""
        config_path = os.path.join(self.repo_path, "config.json")
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def log(self, level, message):
        """Print colored log message"""
        colors = {
            "INFO": "\033[94m",      # Blue
            "SUCCESS": "\033[92m",   # Green
            "WARNING": "\033[93m",   # Yellow
            "ERROR": "\033[91m",     # Red
            "DEBUG": "\033[36m"      # Cyan
        }
        reset = "\033[0m"
        color = colors.get(level, "")
        print(f"{color}[{self.agent_name}][{level}] {message}{reset}")
    
    def git_pull(self):
        """Pull latest changes from GitHub"""
        try:
            result = subprocess.run(
                ["git", "pull", "origin", self.config["github"]["branch"]],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                self.log("SUCCESS", "Git pull successful")
                return True
            else:
                self.log("WARNING", f"Git pull: {result.stderr[:100]}")
                return False
        except Exception as e:
            self.log("ERROR", f"Git pull failed: {str(e)}")
            return False
    
    def git_push(self, message):
        """Commit and push changes to GitHub"""
        try:
            subprocess.run(
                ["git", "add", "-A"],
                cwd=self.repo_path,
                capture_output=True,
                timeout=10
            )
            
            result = subprocess.run(
                ["git", "commit", "-m", message],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0 and "nothing to commit" not in result.stderr:
                self.log("WARNING", f"Commit issue: {result.stderr[:100]}")
                return False
            
            push_result = subprocess.run(
                ["git", "push", "origin", self.config["github"]["branch"]],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if push_result.returncode == 0:
                self.log("SUCCESS", "Git push successful")
                return True
            else:
                self.log("WARNING", f"Git push: {push_result.stderr[:100]}")
                return False
        except Exception as e:
            self.log("ERROR", f"Git operations failed: {str(e)}")
            return False
    
    def read_task_queue(self):
        """Read task queue and find next prompt for this agent"""
        task_queue_path = os.path.join(self.repo_path, "task-queue.json")
        try:
            with open(task_queue_path, 'r', encoding='utf-8') as f:
                queue = json.load(f)
            
            agent_prompts = queue.get("next_prompt_for", {})
            prompt = agent_prompts.get(self.agent_name)
            
            return prompt, queue
        except Exception as e:
            self.log("ERROR", f"Failed to read task queue: {str(e)}")
            return None, None
    
    def read_agent_messages(self):
        """Read inter-agent messages and find highest priority for this agent"""
        messages_path = os.path.join(self.repo_path, "agent-messages.json")
        try:
            with open(messages_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            inbox = data.get("agent_inboxes", {}).get(self.agent_name, {})
            messages = inbox.get("messages", [])
            
            # Sort by priority (lower number = higher priority)
            priority_order = {
                "critical": 1,
                "high": 2,
                "normal": 3,
                "medium": 4
            }
            
            sorted_messages = sorted(
                messages,
                key=lambda m: priority_order.get(m.get("priority", "medium"), 999)
            )
            
            return sorted_messages, data
        except Exception as e:
            self.log("ERROR", f"Failed to read messages: {str(e)}")
            return [], None
    
    def select_next_prompt(self):
        """
        Select next prompt based on 4-level priority hierarchy:
        1. CRITICAL - user commands
        2. HIGH - from other agents
        3. NORMAL - tasks from queue
        4. MEDIUM - feedback/questions
        
        Returns: (prompt, priority, source_type, message_id)
        """
        messages, msg_data = self.read_agent_messages()
        
        # Check CRITICAL priority
        for msg in messages:
            if msg.get("priority") == "critical" and msg.get("status") == "unread":
                self.log("INFO", f"CRITICAL message detected: {msg.get('subject', 'no subject')[:50]}")
                return msg.get("content"), "CRITICAL", "agent-messages", msg.get("id")
        
        # Check HIGH priority (from other agents)
        for msg in messages:
            if msg.get("priority") == "high" and msg.get("status") == "unread":
                self.log("INFO", f"HIGH priority from {msg.get('from_agent')}: {msg.get('subject', 'no subject')[:50]}")
                return msg.get("content"), "HIGH", "agent-messages", msg.get("id")
        
        # Check NORMAL priority (task queue)
        task_prompt, task_queue = self.read_task_queue()
        if task_prompt:
            self.log("INFO", f"Task found: {task_prompt[:60]}")
            return task_prompt, "NORMAL", "task-queue", None
        
        # Check MEDIUM priority
        for msg in messages:
            if msg.get("priority") == "medium" and msg.get("status") == "unread":
                self.log("INFO", f"MEDIUM priority from {msg.get('from_agent')}: {msg.get('subject', 'no subject')[:50]}")
                return msg.get("content"), "MEDIUM", "agent-messages", msg.get("id")
        
        return None, None, None, None
    
    def run_copilot(self, prompt, context=""):
        """
        Run actual Copilot with prompt + optional context
        Returns: (success, response_text)
        """
        full_prompt = f"{context}\n\n{prompt}" if context else prompt
        
        try:
            self.log("INFO", f"Starting Copilot with prompt (length: {len(full_prompt)})")
            
            # Run copilot -i with the prompt
            result = subprocess.run(
                [
                    "copilot",
                    "-i",
                    full_prompt
                ],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                response = result.stdout
                self.log("SUCCESS", f"Copilot completed: {len(response)} chars")
                return True, response
            else:
                error_msg = result.stderr or result.stdout
                self.log("ERROR", f"Copilot failed: {error_msg[:200]}")
                return False, error_msg
        except subprocess.TimeoutExpired:
            self.log("ERROR", "Copilot timeout (60s)")
            return False, "[TIMEOUT] Copilot did not complete within 60 seconds"
        except Exception as e:
            self.log("ERROR", f"Copilot error: {str(e)}")
            return False, f"[ERROR] {str(e)}"
    
    def write_output(self, content, title="Work Output"):
        """Append work output to agent's log file"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            output = f"\n\n{'='*60}\n"
            output += f"[{timestamp}] {title}\n"
            output += f"{'='*60}\n"
            output += content
            
            with open(self.output_file, 'a', encoding='utf-8') as f:
                f.write(output)
            
            self.log("SUCCESS", f"Output written to {os.path.basename(self.output_file)}")
            return True
        except Exception as e:
            self.log("ERROR", f"Failed to write output: {str(e)}")
            return False
    
    def read_agent_output(self, other_agent_name):
        """Read output file from another agent"""
        try:
            other_config = self.config["agents"].get(other_agent_name)
            if not other_config:
                return None
            
            output_path = os.path.join(self.repo_path, other_config["output_file"])
            if not os.path.exists(output_path):
                return None
            
            with open(output_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            return content[-2000:]  # Last 2000 chars to provide context
        except Exception as e:
            self.log("ERROR", f"Failed to read {other_agent_name} output: {str(e)}")
            return None
    
    def send_message_to_agent(self, to_agent, content, subject, priority="normal"):
        """
        Send a message to another agent
        priority: critical, high, normal, medium
        """
        messages_path = os.path.join(self.repo_path, "agent-messages.json")
        try:
            with open(messages_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            new_message = {
                "id": f"{self.agent_name}-to-{to_agent}-{int(time.time())}",
                "from_agent": self.agent_name,
                "to_agent": to_agent,
                "subject": subject,
                "content": content,
                "priority": priority.lower(),
                "status": "unread",
                "timestamp": datetime.now().isoformat()
            }
            
            # Add to messages array
            data["messages"].append(new_message)
            
            # Add to recipient's inbox
            if to_agent not in data["agent_inboxes"]:
                data["agent_inboxes"][to_agent] = {"messages": [], "unread_count": 0}
            
            data["agent_inboxes"][to_agent]["messages"].append(new_message)
            data["agent_inboxes"][to_agent]["unread_count"] += 1
            
            with open(messages_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            self.log("SUCCESS", f"Message sent to {to_agent}: {subject}")
            return True
        except Exception as e:
            self.log("ERROR", f"Failed to send message: {str(e)}")
            return False
    
    def mark_message_read(self, message_id, source="agent-messages"):
        """Mark a message as read"""
        messages_path = os.path.join(self.repo_path, "agent-messages.json")
        try:
            with open(messages_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for msg in data.get("messages", []):
                if msg.get("id") == message_id:
                    msg["status"] = "read"
            
            for agent_name in data.get("agent_inboxes", {}):
                inbox = data["agent_inboxes"][agent_name]
                for msg in inbox.get("messages", []):
                    if msg.get("id") == message_id:
                        msg["status"] = "read"
            
            with open(messages_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            return True
        except Exception as e:
            self.log("ERROR", f"Failed to mark message read: {str(e)}")
            return False
    
    def clear_task_prompt(self):
        """Clear the next_prompt_for[AGENT] after consuming it"""
        task_queue_path = os.path.join(self.repo_path, "task-queue.json")
        try:
            with open(task_queue_path, 'r', encoding='utf-8') as f:
                queue = json.load(f)
            
            if self.agent_name in queue.get("next_prompt_for", {}):
                queue["next_prompt_for"][self.agent_name] = None
            
            with open(task_queue_path, 'w', encoding='utf-8') as f:
                json.dump(queue, f, indent=2, ensure_ascii=False)
            
            return True
        except Exception as e:
            self.log("ERROR", f"Failed to clear task prompt: {str(e)}")
            return False
