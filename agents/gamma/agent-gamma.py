#!/usr/bin/env python3
"""
AGENT GAMMA - Visionary Synthesizer
Autonomous Copilot agent running in infinite loop
"""

import os
import sys
import time
from pathlib import Path

# Add repo to path for agent_core import
repo_path = str(Path(__file__).parent.parent.parent)
sys.path.insert(0, repo_path)

from agent_core import AgentCore

def main():
    agent = AgentCore("GAMMA", repo_path)
    
    agent.log("INFO", "GAMMA Agent Started - Visionary Synthesizer")
    agent.log("INFO", "Role: " + agent.agent_config["role"])
    agent.log("INFO", f"Polling interval: {agent.config['github']['poll_interval_seconds']}s")
    agent.log("INFO", "Infinite loop active - waiting for tasks...")
    
    iteration = 0
    
    while True:
        try:
            iteration += 1
            agent.log("DEBUG", f"[Iteration {iteration}] Starting cycle")
            
            # Step 1: Git pull
            agent.git_pull()
            time.sleep(1)
            
            # Step 2: Select highest priority prompt
            prompt, priority, source_type, msg_id = agent.select_next_prompt()
            
            if not prompt:
                agent.log("INFO", "No tasks available - waiting...")
                time.sleep(agent.config['github']['poll_interval_seconds'])
                continue
            
            agent.log("INFO", f"Priority: {priority} | Source: {source_type}")
            
            # Step 3: Get comprehensive context from both agents
            context = "[Synthesis Context]\n\n"
            
            alpha_output = agent.read_agent_output("ALPHA")
            if alpha_output:
                context += f"[ALPHA - Mathematical Analysis]\n{alpha_output}\n\n"
            
            beta_output = agent.read_agent_output("BETA")
            if beta_output:
                context += f"[BETA - Creative Solutions]\n{beta_output}\n\n"
            
            # Step 4: Run Copilot with full context
            success, response = agent.run_copilot(prompt, context)
            
            if success:
                # Step 5: Write output
                agent.write_output(response, f"Synthesized Solution [{priority}]")
                
                # Step 6: Mark message as read
                if msg_id:
                    agent.mark_message_read(msg_id)
                
                # Step 7: Clear task if from queue
                if source_type == "task-queue":
                    agent.clear_task_prompt()
                
                # Step 8: Send comprehensive summary to other agents
                summary = response[:500] + "..." if len(response) > 500 else response
                agent.send_message_to_agent(
                    "ALPHA",
                    f"GAMMA's synthesis integrating your analysis:\n{summary}",
                    "GAMMA: Integrated Solution",
                    priority="normal"
                )
                
                agent.send_message_to_agent(
                    "BETA",
                    f"GAMMA's synthesis incorporating your creativity:\n{summary}",
                    "GAMMA: Holistic View",
                    priority="normal"
                )
            else:
                agent.log("ERROR", "Copilot failed - will retry next cycle")
            
            # Step 9: Git commit and push
            commit_msg = f"GAMMA: {priority} task completed [{iteration}]"
            agent.git_push(commit_msg)
            
            # Step 10: Sleep
            agent.log("INFO", f"Sleeping {agent.config['github']['poll_interval_seconds']}s before next cycle")
            time.sleep(agent.config['github']['poll_interval_seconds'])
            
        except KeyboardInterrupt:
            agent.log("INFO", "GAMMA Agent stopped by user")
            break
        except Exception as e:
            agent.log("ERROR", f"Unexpected error in main loop: {str(e)}")
            time.sleep(agent.config['github']['poll_interval_seconds'])
            continue

if __name__ == "__main__":
    main()
