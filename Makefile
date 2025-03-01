LARGE_TEST_REPO_DIR:=tests/test_docs_large
GIT_DESC=$$(git describe)
JUNIT_FLAGS := --capture=sys -o junit_logging=all

.PHONY: lint-black
lint-black: ## check python source code formatting issues, with black
	black --check --diff --exclude dev_scripts/envs --exclude $(LARGE_TEST_REPO_DIR) ./

.PHONY: lint-black-apply
lint-black-apply: ## apply black's source code formatting suggestions
	black --exclude dev_scripts/envs --exclude $(LARGE_TEST_REPO_DIR) ./

.PHONY: lint-isort
lint-isort: ## check imports are organized, with isort
	isort --check-only --skip dev_scripts/envs --skip $(LARGE_TEST_REPO_DIR) ./

.PHONY: lint-isort-apply
lint-isort-apply: ## apply isort's imports organization suggestions
	isort --skip dev_scripts/envs --skip $(LARGE_TEST_REPO_DIR) ./

MYPY_ARGS := --ignore-missing-imports \
			 --disallow-incomplete-defs \
			 --disallow-untyped-defs \
			 --show-error-codes \
			 --warn-unreachable \
			 --warn-unused-ignores \
			 --exclude $(LARGE_TEST_REPO_DIR)/*.py

mypy-host:
	mypy $(MYPY_ARGS) dangerzone

mypy-tests:
	mypy $(MYPY_ARGS) tests

mypy: mypy-host mypy-tests ## check type hints with mypy

.PHONY: lint
lint: lint-black lint-isort mypy ## check the code with various linters

.PHONY: lint-apply
lint-apply: lint-black-apply lint-isort-apply ## apply all the linter's suggestions

.PHONY: test
test:
	# Make each GUI test run as a separate process, to avoid segfaults due to
	# shared state.
	# See more in https://github.com/freedomofpress/dangerzone/issues/493
	pytest --co -q tests/gui | grep -v ' collected' | xargs -n 1 pytest -v
	pytest -v --cov --ignore dev_scripts --ignore tests/gui --ignore tests/test_large_set.py


.PHONY: test-large-requirements
test-large-requirements:
	@git-lfs --version || (echo "ERROR: you need to install 'git-lfs'" && false)
	@xmllint --version || (echo "ERROR: you need to install 'xmllint'" && false)

test-large-init: test-large-requirements
	@echo "initializing 'test_docs_large' submodule"
	git submodule init $(LARGE_TEST_REPO_DIR)
	git submodule update $(LARGE_TEST_REPO_DIR)
	cd $(LARGE_TEST_REPO_DIR) && $(MAKE) clone-docs

TEST_LARGE_RESULTS:=$(LARGE_TEST_REPO_DIR)/results/junit/commit_$(GIT_DESC).junit.xml
.PHONY: tests-large
test-large: test-large-init  ## Run large test set
	python -m pytest --tb=no tests/test_large_set.py::TestLargeSet -v $(JUNIT_FLAGS) --junitxml=$(TEST_LARGE_RESULTS)
	python $(TEST_LARGE_RESULTS)/report.py $(TEST_LARGE_RESULTS)

# Makefile self-help borrowed from the securedrop-client project
# Explaination of the below shell command should it ever break.
# 1. Set the field separator to ": ##" and any make targets that might appear between : and ##
# 2. Use sed-like syntax to remove the make targets
# 3. Format the split fields into $$1) the target name (in blue) and $$2) the target descrption
# 4. Pass this file as an arg to awk
# 5. Sort it alphabetically
# 6. Format columns with colon as delimiter.
.PHONY: help
help: ## Print this message and exit.
	@printf "Makefile for developing and testing dangerzone.\n"
	@printf "Subcommands:\n\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[0-9a-zA-Z_-]+:.*?## / {printf "\033[36m%s\033[0m : %s\n", $$1, $$2}' $(MAKEFILE_LIST) \
		| sort \
		| column -s ':' -t
