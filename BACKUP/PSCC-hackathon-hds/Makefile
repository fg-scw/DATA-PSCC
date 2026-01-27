#!make
#===============================================================================
# HACKATHON HDS - Makefile
#===============================================================================

.PHONY: all init plan apply destroy clean help fmt validate

# Default target
all: init validate plan

#-------------------------------------------------------------------------------
# Terraform operations
#-------------------------------------------------------------------------------

init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: ## Plan infrastructure changes
	terraform plan -out=tfplan

apply: ## Apply infrastructure changes
	terraform apply tfplan
	@echo ""
	@echo "Deployment complete! See ACCESS.md for access information."

apply-auto: ## Apply without confirmation (use with caution)
	terraform apply -auto-approve
	@echo ""
	@echo "Deployment complete! See ACCESS.md for access information."

destroy: ## Destroy all infrastructure (with confirmation)
	@echo "WARNING: This will destroy ALL hackathon infrastructure!"
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy

destroy-auto: ## Destroy without confirmation (DANGEROUS)
	terraform destroy -auto-approve

#-------------------------------------------------------------------------------
# Dry-run mode
#-------------------------------------------------------------------------------

plan-dry: ## Plan in dry-run mode (no user invitations)
	terraform plan -var="dry_run=true" -out=tfplan

apply-dry: ## Apply in dry-run mode (no user invitations)
	terraform apply -var="dry_run=true" -auto-approve
	@echo ""
	@echo "DRY-RUN deployment complete! No invitations sent."
	@echo "Set dry_run=false for production deployment."

plan-prod: ## Plan in production mode (with user invitations)
	terraform plan -var="dry_run=false" -out=tfplan

apply-prod: ## Apply in production mode (with user invitations)
	@echo "WARNING: This will send invitation emails to all users!"
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ]
	terraform apply -var="dry_run=false" -auto-approve

#-------------------------------------------------------------------------------
# Data operations
#-------------------------------------------------------------------------------

upload-zone1: ## Upload data to Zone 1 (usage: make upload-zone1 DIR=/path/to/data)
	@if [ -z "$(DIR)" ]; then \
		echo "Usage: make upload-zone1 DIR=/path/to/data"; \
		exit 1; \
	fi
	./scripts/upload-to-zone1.sh $(DIR)

upload-zone2: ## Upload data to Zone 2 (usage: make upload-zone2 DIR=/path/to/data)
	@if [ -z "$(DIR)" ]; then \
		echo "Usage: make upload-zone2 DIR=/path/to/data"; \
		exit 1; \
	fi
	./scripts/upload-to-zone2.sh $(DIR)

#-------------------------------------------------------------------------------
# Utility operations
#-------------------------------------------------------------------------------

show-access: ## Show access information
	@cat ACCESS.md

show-teams: ## List all teams with SSH commands
	@terraform output -json team_ssh_commands 2>/dev/null | jq -r '.[]' || echo "Run 'make apply' first"

show-keys: ## Show encryption keys location
	@echo "Encryption keys stored in:"
	@ls -la keys/*.txt 2>/dev/null || echo "No keys found. Run 'make apply' first."

show-mode: ## Show current deployment mode
	@terraform output -raw dry_run_mode 2>/dev/null && echo "" || echo "Run 'make apply' first"

package-credentials: ## Package credentials for distribution
	@mkdir -p dist
	@for team in keys/*/; do \
		team_name=$$(basename $$team); \
		if [ "$$team_name" != "admin" ]; then \
			echo "Packaging $$team_name..."; \
			zip -j "dist/$$team_name-credentials.zip" "$$team"/* 2>/dev/null || true; \
		fi; \
	done
	@echo ""
	@echo "Credentials packaged in dist/ directory"
	@ls -la dist/

#-------------------------------------------------------------------------------
# Cleanup
#-------------------------------------------------------------------------------

clean: ## Clean generated files (keeps state)
	rm -rf dist/
	rm -f tfplan
	rm -f ACCESS.md

clean-all: clean ## Clean everything including state (DANGEROUS)
	rm -rf .terraform
	rm -f terraform.tfstate*
	rm -rf keys/

#-------------------------------------------------------------------------------
# Help
#-------------------------------------------------------------------------------

help: ## Show this help
	@echo "Hackathon HDS - Infrastructure Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  1. cp terraform.tfvars.example terraform.tfvars"
	@echo "  2. Edit terraform.tfvars with your values"
	@echo "  3. make init"
	@echo "  4. make apply-dry    # Test without sending invitations"
	@echo "  5. make apply-prod   # Production deployment"
