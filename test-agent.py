import sys
import os
from pathlib import Path

repo_path = r'C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow'
sys.path.insert(0, repo_path)

from agent_core import AgentCore

agent = AgentCore("ALPHA", repo_path)

print("\n" + "="*60)
print("🤖 ALPHA TEST RUN - 1 Iteration")
print("="*60)
print(f"Agent: ALPHA")
print(f"Role: {agent.agent_config['role']}")
print(f"Repo: {repo_path}")
print("="*60 + "\n")

# ONE ITERATION ONLY
try:
    print("[TEST] Starting git pull...")
    agent.git_pull()
    
    print("\n[TEST] Checking for prompts...")
    prompt, priority, source_type, msg_id = agent.select_next_prompt()
    
    if prompt:
        print(f"[TEST] Found prompt (priority={priority}):")
        print(f"  {prompt[:100]}...")
    else:
        print("[TEST] No prompt found in queue or messages")
        print("[TEST] Checking task-queue.json content...")
        import json
        with open(os.path.join(repo_path, 'task-queue.json')) as f:
            queue = json.load(f)
        print(json.dumps(queue, indent=2)[:500])
        
except Exception as e:
    print(f"[ERROR] {str(e)}")
    import traceback
    traceback.print_exc()

print("\n[TEST] Agent test complete!")
