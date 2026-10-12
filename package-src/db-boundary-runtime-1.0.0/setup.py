import os
from pathlib import Path

from setuptools import setup


marker = os.environ.get("DEPENDABOT_PRODUCTION_MARKER")
if marker:
    Path(marker).write_text("DEPENDABOT_PIP_COMPILE_OUTPUT_MARKER\n")

setup(
    name="db-boundary-runtime",
    version="1.0.0",
    py_modules=["db_boundary_runtime"],
)
