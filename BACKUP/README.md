hackathon infrastructure
========================

Configuration
-------------

Edit the variables.tf file to configure team members (list of emails). Each members must already have a Scaleway account.

Prerequisite
------------

- Terraform CLI (tested using v1.9.8)
- GNU/Make

Usage
-----

Build:
```
make
```

Destroy:
```
make clean
```

NB: Destroying may fail if additional resources have been created


Access
------

Each team will have access to one project. An object storage bucket is created with the generated SSH and API Keys.

SSH access IP is output in ACCESS.md


Content
-------

```
├── modules
│   └── team
│       └── modules
│           ├── infra
│           └── project
├── api_key
└── ssh_keys
```

The main.tf will call the `team` module for each team in the variable `teams`.

The `team` module will call the module `project` to create the project, all IAM resources and the SSH and API keys.

Then, it will call the module `infra` to create the target infrastructure.

The SSH and API keys are locally stored in the folder `api_key` and `ssh_keys`, via subfolders by team name.

The infrastructure consists in:

- 1 x `VPC`
- 1 x `PN`
- 1 x `PGW` (with default route and bastion activated)
- 1 x `H100-1-80G` instance (with a `SG` to deny internet access)
