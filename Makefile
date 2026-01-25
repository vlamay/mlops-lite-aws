SHELL := /bin/bash

.PHONY: fmt lint test tf-init tf-validate tf-plan tf-apply

fmt:
	terraform -chdir=infra/terraform fmt -recursive
	python -m compileall -q .

lint:
	python -m pip install -q ruff
	ruff check ml service

test:
	pytest -q

tf-init:
	terraform -chdir=infra/terraform init -upgrade

tf-validate:
	terraform -chdir=infra/terraform validate

tf-plan:
	terraform -chdir=infra/terraform plan -out=tfplan

tf-apply:
	terraform -chdir=infra/terraform apply tfplan
