import sys
import os
import json
import time
from pathlib import Path

repo_path = r'C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow'
sys.path.insert(0, repo_path)

from agent_core import AgentCore

agent = AgentCore("ALPHA", repo_path)

print("\n" + "="*70)
print("🤖 FULL ALPHA EXECUTION TEST")
print("="*70)

# STEP 1: Git pull
print("\n[STEP 1] Git pull...")
agent.git_pull()

# STEP 2: Select prompt
print("\n[STEP 2] Select next prompt...")
prompt, priority, source_type, msg_id = agent.select_next_prompt()

if not prompt:
    print("ERROR: No prompt found!")
    sys.exit(1)

print(f"✓ Found prompt (priority={priority})")
print(f"  Prompt: {prompt[:80]}")

# STEP 3: Run copilot
print("\n[STEP 3] Running Copilot...")
print(f"  Executing: copilot -i \"{prompt}\"")

success, response = agent.run_copilot(prompt)

if not success:
    print(f"✗ Copilot failed: {response[:200]}")
    sys.exit(1)

print(f"✓ Copilot executed!")
print(f"  Response length: {len(response)} chars")
print(f"  First 300 chars: {response[:300]}")

# STEP 4: Write output
print("\n[STEP 4] Writing output...")
agent.write_output(response, f"TEST EXECUTION [{priority}]")

# STEP 5: Send message to BETA
print("\n[STEP 5] Sending message to BETA...")
summary = response[:200].replace('\n', ' ')
agent.send_message_to_agent(
    "BETA",
    f"ALPHA test complete. Response: {summary}",
    "ALPHA: Test Complete",
    priority="high"
)

# STEP 6: Git push
print("\n[STEP 6] Pushing to GitHub...")
agent.git_push("ALPHA: Test execution complete")

print("\n" + "="*70)
print("✓ TEST COMPLETE!")
print("="*70)

# Show what was written
print("\nChecking output file...")
with open(agent.output_file, 'r') as f:
    content = f.read()
    print(f"Output file size: {len(content)} chars")
    print(f"Last 500 chars:\n{content[-500:]}")

