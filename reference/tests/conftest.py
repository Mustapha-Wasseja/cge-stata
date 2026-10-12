import os
import sys
from pathlib import Path

# Single-threaded BLAS: set before numpy is first imported (see cge_ref/__init__.py).
for var in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(var, "1")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
