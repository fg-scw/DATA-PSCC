# Hackathon HDS - Guide de Déploiement

## Prérequis

```bash
# Installer Terraform >= 1.5
brew install terraform

# Configurer le profil Scaleway
scw init
```

## Déploiement

```bash
# 1. Copier et éditer la configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Initialiser Terraform
make init

# 2Bis. Validate Terraform
make validate

# 3. Déployer en mode test (sans invitations)
make dry-run

# 4. Déployer en production (avec invitations)
make prod
```

## Commandes utiles

```bash
# Afficher les infos d'accès
make show

# Lister les commandes SSH
make teams

# Se connecter à une équipe
make ssh TEAM=atos

# Détruire l'infrastructure
make destroy
```

## Structure des credentials

```
keys/
├── zone1_encryption_key.txt      # Clé SSE-C Zone 1
├── zone2_encryption_key.txt      # Clé SSE-C Zone 2
├── livrables_encryption_key.txt  # Clé SSE-C Livrables
├── admin/
│   └── api_credentials.env
├── <team-slug>/
│   ├── ssh_private_key.pem
│   ├── api_credentials.env
│   └── credentials.md
└── <provider-slug>/
    ├── api_credentials.env
    └── portal_credentials.txt    # Si upload portal activé
```

## Test partiel

Pour déployer uniquement certaines équipes, commenter les autres dans `terraform.tfvars`:

```hcl
teams = {
  team01 = { ... }  # Déployé
  # team02 = { ... }  # Ignoré
}
```
