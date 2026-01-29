.PHONY: init plan apply destroy clean help distribute

# Terraform
init:
	terraform init

validate:
	terraform validate

plan:
	terraform plan -out=tfplan


apply:
	terraform apply tfplan

apply-auto:
	terraform apply -auto-approve

destroy:
	terraform destroy

# Shortcuts
dry-run: init
	terraform apply -var="dry_run=true" -auto-approve

prod: init
	terraform apply -var="dry_run=false" -auto-approve

# Utils
ssh:
	@if [ -z "$(TEAM)" ]; then echo "Usage: make ssh TEAM=<slug>"; exit 1; fi
	@CMD=$$(terraform output -json team_access | jq -r 'to_entries[] | select(.key | ascii_downcase | contains("$(TEAM)")) | .value.ssh_command' | head -1); \
	echo "$$CMD"; eval "$$CMD"

ssh-portal:
	@CMD=$$(terraform output -json upload_portal | jq -r '.ssh_command'); \
	echo "$$CMD"; eval "$$CMD"

show:
	@cat ACCESS.md

teams:
	@terraform output -json team_ssh_commands | jq -r '.[]'

distribute:
	@chmod +x scripts/distribute-credentials.sh
	@./scripts/distribute-credentials.sh

clean:
	rm -f tfplan ACCESS.md
	rm -rf .terraform distribution keys


help:
	@echo "Commands:"
	@echo "  make init         - Initialize Terraform"
	@echo "  make dry-run      - Deploy without IAM users"
	@echo "  make prod         - Production deployment"
	@echo "  make destroy      - Destroy infrastructure"
	@echo "  make ssh TEAM=x   - SSH to team GPU"
	@echo "  make ssh-portal   - SSH to upload portal"
	@echo "  make show         - Show access info"
	@echo "  make teams        - List SSH commands"
	@echo "  make distribute   - Package credentials for distribution"
