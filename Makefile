# Copyright 2018, 2019 EnergyLink Support Pty Ltd. All rights reserved.
#
# Makefile --
#
#       This file defines the make targets for
#       validating/testing/etc the terraform code.
#

AWS_DEFAULT_REGION ?= ap-southeast-2
AWS_VAULT_PROFILE ?= kb-superuser
TF_PROJECT ?=

AWS_VAULT_EXEC = AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) aws-vault exec $(AWS_VAULT_PROFILE) --

.PHONY: apply cache clean destroy format init plan pre-commit validate test

.terraform:
	$(AWS_VAULT_EXEC) terraform init $(TF_PROJECT)

apply: plan
	$(AWS_VAULT_EXEC) terraform apply terraform.tfplan
	rm -rf terraform.tfplan

clean:
	echo "Cleaning up old environment..."
	rm -rf $(TF_PROJECT)/.terraform
	rm -rf .terraform
	rm -rf terraform.tfplan

destroy: init
	$(AWS_VAULT_EXEC) terraform destroy -auto-approve $(TF_PROJECT)

format:
	terraform fmt && terraform fmt $(TF_PROJECT)

init: .terraform

plan: terraform.tfplan

terraform.tfplan: .terraform main.tf variables.tf $(TF_PROJECT)
	$(AWS_VAULT_EXEC) terraform plan -out $@ $(TF_PROJECT)

validate: init
	terraform validate $(TF_PROJECT)
