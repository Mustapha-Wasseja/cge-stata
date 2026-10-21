"""Python reference implementation of the cge-stata model (docs/model_spec.md)."""

import os

# The model's matrices are small; multithreaded BLAS only adds overhead and,
# with OpenBLAS on Windows, can slow solves by an order of magnitude. This
# takes effect only if numpy has not been imported yet.
for _var in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_var, "1")

from .model import VARIABLES, Closure, Model, Solution  # noqa: E402
from .optimize import Instrument, optimize  # noqa: E402
from .report import report  # noqa: E402
from .sam import SAM, Mapping, SAMError, prepare  # noqa: E402

__all__ = ["VARIABLES", "Closure", "Instrument", "Mapping", "Model", "SAM", "SAMError", "Solution", "optimize",
           "prepare", "report"]
