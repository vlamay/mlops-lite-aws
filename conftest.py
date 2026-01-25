import os
import sys


# Ensure repo root is on sys.path for CI runs
REPO_ROOT = os.path.dirname(__file__)
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)
