#!/usr/bin/env python3
"""
AGENT ALPHA - Deep Mathematician
Autonomous Copilot agent running in infinite loop
"""

import os
import sys
import time
from pathlib import Path

# Add repo to path for agent_core import
repo_path = str(Path(__file__).parent)
sys.path.insert(0, repo_path)

from agent_core import AgentCore

def main():
    agent = AgentCore("ALPHA", repo_path)
    
    agent.log("INFO", "ALPHA Agent Started - Deep Mathematician")
    agent.log("INFO", "Role: " + agent.agent_config["role"])
    agent.log("INFO", f"Polling interval: {agent.config['github']['poll_interval_seconds']}s")
    agent.log("INFO", "Infinite loop active - waiting for tasks...")
    
    iteration = 0
    
    while True:
        try:
            iteration += 1
            agent.log("DEBUG", f"[Iteration {iteration}] Starting cycle")
            
            # Step 1: Git pull for latest changes
            agent.git_pull()
            time.sleep(1)
            
            # Step 2: Select highest priority prompt
            prompt, priority, source_type, msg_id = agent.select_next_prompt()
            
            if not prompt:
                agent.log("INFO", "No tasks available - waiting...")
                time.sleep(agent.config['github']['poll_interval_seconds'])
                continue
            
            agent.log("INFO", f"Priority: {priority} | Source: {source_type}")
            
            # Step 3: Get context from other agents if HIGH priority
            context = ""
            if priority == "HIGH":
                # Read BETA's latest work for context
                beta_output = agent.read_agent_output("BETA")
                if beta_output:
                    context = f"[BETA's latest work for context]\n{beta_output}"
                
                gamma_output = agent.read_agent_output("GAMMA")
                if gamma_output:
                    context += f"\n\n[GAMMA's latest work for context]\n{gamma_output}"
            
            # Step 4: Run Copilot with the prompt
            success, response = agent.run_copilot(prompt, context)
            
            if success:
                # Step 5: Write output
                agent.write_output(response, f"Task Response [{priority}]")
                
                # Step 6: Mark message as read if it was from messages
                if msg_id:
                    agent.mark_message_read(msg_id)
                
                # Step 7: Clear task if from queue
                if source_type == "task-queue":
                    agent.clear_task_prompt()
                
                # Step 8: Send feedback/next steps to other agents if appropriate
                if priority in ["NORMAL", "HIGH"]:
                    summary = response[:500] + "..." if len(response) > 500 else response
                    agent.send_message_to_agent(
                        "BETA",
                        f"ALPHA completed analysis. Summary:\n{summary}",
                        "ALPHA: Analysis Complete",
                        priority="high"
                    )
                    
                    agent.send_message_to_agent(
                        "GAMMA",
                        f"ALPHA has new findings for synthesis:\n{summary}",
                        "ALPHA: New Findings",
                        priority="normal"
                    )
            else:
                agent.log("ERROR", "Copilot failed - will retry next cycle")
            
            # Step 9: Git commit and push
            commit_msg = f"ALPHA: {priority} task completed [{iteration}]"
            agent.git_push(commit_msg)
            
            # Step 10: Sleep before next cycle
            agent.log("INFO", f"Sleeping {agent.config['github']['poll_interval_seconds']}s before next cycle")
            time.sleep(agent.config['github']['poll_interval_seconds'])
            
        except KeyboardInterrupt:
            agent.log("INFO", "ALPHA Agent stopped by user")
            break
        except Exception as e:
            agent.log("ERROR", f"Unexpected error in main loop: {str(e)}")
            time.sleep(agent.config['github']['poll_interval_seconds'])
            continue

if __name__ == "__main__":
    main()
