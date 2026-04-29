#!/usr/bin/env python3
"""Quick launcher for Master Control interface"""

import os
import sys
from pathlib import Path

repo_path = str(Path(__file__).parent)
os.chdir(repo_path)

sys.path.insert(0, repo_path)

import master_control

if __name__ == "__main__":
    master_control.main()
