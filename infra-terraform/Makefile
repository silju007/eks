# EKS platform Terraform — per-project driver.
#
# Usage:
#   make init    PROJECT=example-project ROOT=bootstrap
#   make apply   PROJECT=example-project ROOT=bootstrap
#   make output  PROJECT=example-project ROOT=bootstrap      # grab the state bucket name
#   # paste bucket into projects/example-project/backend.hcl, then:
#   make init    PROJECT=example-project ROOT=global
#   make apply   PROJECT=example-project ROOT=global
#   make init    PROJECT=example-project ROOT=shared
#   make apply   PROJECT=example-project ROOT=shared
#
# ROOT is one of: bootstrap | global | shared
# fmt is repo-wide and needs no PROJECT/ROOT.

SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT ?=
ROOT    ?=

# CI: set AUTO=1 to skip the interactive approval on apply/destroy.
AUTO ?=
ifeq ($(AUTO),1)
  APPROVE := -auto-approve
else
  APPROVE :=
endif

PROJECT_DIR := $(CURDIR)/projects/$(PROJECT)

# Map ROOT -> working directory, per-root var file, and whether it uses the
# remote (S3) backend. bootstrap uses local state (no backend-config).
ifeq ($(ROOT),bootstrap)
  DIR          := bootstrap
  ROOT_VARS    := bootstrap.tfvars
  USE_BACKEND  := no
else ifeq ($(ROOT),global)
  DIR          := global
  ROOT_VARS    := global.tfvars
  USE_BACKEND  := yes
else ifeq ($(ROOT),shared)
  DIR          := environments/shared
  ROOT_VARS    := shared.tfvars
  USE_BACKEND  := yes
endif

# EXTRA lets callers append raw args (later -var wins over the var-files).
# CI uses it to blank out aws_profile so the OIDC web-identity chain is used:
#   make apply ... EXTRA='-var=aws_profile='
EXTRA ?=
VAR_ARGS := -var-file=$(PROJECT_DIR)/common.tfvars -var-file=$(PROJECT_DIR)/$(ROOT_VARS) $(EXTRA)

ifeq ($(USE_BACKEND),yes)
  BACKEND_ARGS := -backend-config=$(PROJECT_DIR)/backend.hcl
else
  BACKEND_ARGS :=
endif

TF := terraform -chdir=$(DIR)

# ---- guards -----------------------------------------------------------------
.PHONY: guard-project guard-root
guard-project:
	@if [ -z "$(PROJECT)" ]; then echo "ERROR: set PROJECT=<name> (see projects/)"; exit 1; fi
	@if [ ! -d "$(PROJECT_DIR)" ]; then echo "ERROR: no such project dir: $(PROJECT_DIR)"; exit 1; fi
guard-root:
	@if [ -z "$(DIR)" ]; then echo "ERROR: set ROOT=bootstrap|global|shared"; exit 1; fi

# ---- terraform lifecycle ----------------------------------------------------
.PHONY: init plan apply destroy validate output refresh
init: guard-project guard-root ## Init a root for a project (wires backend + providers)
	$(TF) init $(BACKEND_ARGS) -input=false

plan: guard-project guard-root ## Show a plan
	$(TF) plan $(VAR_ARGS) -input=false

apply: guard-project guard-root ## Apply changes (AUTO=1 to skip approval, for CI)
	$(TF) apply $(VAR_ARGS) $(APPROVE) -input=false

destroy: guard-project guard-root ## Destroy the root's resources (AUTO=1 to skip approval)
	$(TF) destroy $(VAR_ARGS) $(APPROVE) -input=false

validate: guard-root ## Validate a root (no project needed)
	$(TF) validate

output: guard-project guard-root ## Show outputs (e.g. bootstrap's backend_hcl)
	$(TF) output

refresh: guard-project guard-root ## Refresh state
	$(TF) refresh $(VAR_ARGS) -input=false

# ---- repo-wide helpers ------------------------------------------------------
.PHONY: fmt fmt-check new-project help
fmt: ## Format every .tf file in the repo
	terraform fmt -recursive

fmt-check: ## Check formatting (CI)
	terraform fmt -recursive -check

new-project: ## Scaffold a new project: make new-project NAME=foo
	@if [ -z "$(NAME)" ]; then echo "ERROR: set NAME=<project>"; exit 1; fi
	@if [ -d "projects/$(NAME)" ]; then echo "ERROR: projects/$(NAME) already exists"; exit 1; fi
	@cp -r projects/_template projects/$(NAME)
	@echo "Created projects/$(NAME) — edit the .tfvars + backend.hcl, then:"
	@echo "  make apply PROJECT=$(NAME) ROOT=bootstrap"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
