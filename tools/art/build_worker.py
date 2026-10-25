"""Compatibility entry point for the current skinned character authoring pipeline."""
import runpy
from pathlib import Path

runpy.run_path(str(Path(__file__).with_name('build_realistic_worker.py')),run_name='__main__')
