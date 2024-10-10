# Makefile for mflux Python 3.10+ project, using 3.11 as recommended Python as of Sep 2024

PYTHON_VERSION = 3.11
VENV_DIR = .venv
PYTHON = $(VENV_DIR)/bin/python

# Default target
.PHONY: all
all: install test

.PHONY: expect-arm64
expect-arm64:
	# 🖥️ Checking for compatible machine
	@if [ "$$(uname -m)" != "arm64" ]; then \
		echo "mflux and MLX is not compatible with older Intel Macs. This project does not support your Mac."; \
		exit 1; \
	fi

# we "expect" uv but should not install it for the user, let user *choose* to trust a third party installer
.PHONY: expect-uv
expect-uv:
	@if ! /usr/bin/which -s uv; then \
		echo "You can use classic python -m venv to setup this project, \nbut we officially support using uv for managing this project's environment.\n"; \
		echo "Please install uv to continue:\n    https://github.com/astral-sh/uv?tab=readme-ov-file#installation"; \
	fi

# assume reasonably pre-commit is a safe dependency given its wide support (e.g. GitHub Actions integration)
.PHONY: ensure-pre-commit
ensure-pre-commit:
	@if ! /usr/bin/which -s pre-commit; then \
		echo "pre-commit required for submitting commits before pull requests. Using uv tool to install pre-commit."; \
		uv tool install pre-commit; \
	fi


# assume reasonably that if user has installed uv, they trust ruff from the same team
.PHONY: ensure-ruff
ensure-ruff:
	@if ! /usr/bin/which -s ruff; then \
		echo "ruff required for code linting and formatting. Using uv tool to install ruff."; \
		uv tool install ruff; \
	fi

# ensure pytest is available
.PHONY: ensure-pytest
ensure-pytest:
	@if ! $(PYTHON) -c "import pytest" 2>/dev/null; then \
		echo "pytest required for testing. Installing pytest..."; \
		uv pip install pytest; \
	fi

# Create virtual environment with uv
.PHONY: venv-init
venv-init: expect-arm64 expect-uv
	# 🏗️ Creating virtual environment with recommended uv tool:
	uv python install --quiet $(PYTHON_VERSION)
	uv venv --python $(PYTHON_VERSION)
	# ✅ "Python $(PYTHON_VERSION) Virtual environment created at $(VENV_DIR)"

# Install dependencies
.PHONY: install
install: venv-init ensure-pre-commit
	# 🏗️ Installing dependencies and pre-commit hooks...
	uv pip install -e .
	# ✅ Dependencies installed.
	pre-commit install
	# ✅ Pre-commit hooks installed.

# Run linters
.PHONY: lint
lint: ensure-ruff
	# 🏗️ Running linters, your files will not be mutated.
	# Use 'make check' to auto-apply fixes."
	ruff check
	# ✅ Linting complete."

# Run formatter (if dev does not do so in their IDE)
.PHONY: format
format: ensure-ruff
	# 🏗️ Running formatter, your files will be changed to comply to formatting configs.
	ruff format
	# display the summaries of diffs in repo, some of these diffs are generated by the formatter
	git diff --stat
	# ✅ Formatting complete. Please review your git diffs, if any.

# Run ruff auto lint and format via pre-commit hook
.PHONY: check
check: ensure-ruff
	# 🏗️ Running pre-commit linter and formatters on files...
	@(pre-commit run --all-files)

# Run tests
.PHONY: test
test: ensure-pytest
	# 🏗️ Running tests...
	$(PYTHON) -m pytest
	# ✅ Tests completed

# Clean up
.PHONY: clean
clean:
	# 🧼 Cleaning up venv.
	rm -rf $(VENV_DIR)
	# ✅ Cleaned up venv. Run 'make install' to re-generate.

# Help message
.PHONY: help
help:
	@echo "mflux commands:"
	@echo "  make all         - Set up the project and run tests"
	@echo "  make install     - Install project dev dependencies"
	@echo "  make lint        - Run ruff python linter"
	@echo "  make format      - Run ruff code formatter"
	@echo "  make check       - Run linters auto fixes *and* style formatter via pre-commit hook"
	@echo "  make test        - Run tests"
	@echo "  make clean       - Remove the virtual environment"
	@echo "  make help        - Show this help message"
