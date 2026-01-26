#!make

include .hackathonrc

.PHONY: all build clean remove-state dist-clean

all: .terraform build

.terraform:
	terraform init

test:
	terraform plan --var "org_id=${SCW_DEFAULT_ORGANIZATION_ID}" --var "zone_id=${SCW_DEFAULT_ZONE}"

build:
	terraform apply --auto-approve --var "org_id=${SCW_DEFAULT_ORGANIZATION_ID}" --var "zone_id=${SCW_DEFAULT_ZONE}"
	@./access.sh

clean:
	- terraform apply --destroy --auto-approve --var "org_id=${SCW_DEFAULT_ORGANIZATION_ID}" --var "zone_id=${SCW_DEFAULT_ZONE}"
	- echo '' > ACCESS.md

remove-state:
	- rm -rf .terraform terraform.tfstate terraform.tfstate.backup

dist-clean: clean remove-state

