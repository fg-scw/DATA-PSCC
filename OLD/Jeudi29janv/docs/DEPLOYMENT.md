# Hackathon HDS - Guide de Deploiement

## Prerequis

```bash
# Installer Terraform >= 1.5
brew install terraform

# Configurer le profil Scaleway
scw init
```

## Deploiement

```bash
# 1. Copier et editer la configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Initialiser Terraform
make init

# 3. Deployer en mode test (sans invitations)
make dry-run

# 4. Deployer en production (avec invitations)
make prod
```

## Commandes utiles

```bash
# Afficher les infos acces
make show

# Lister les commandes SSH
make teams

# Se connecter a une equipe
make ssh TEAM=atos

# Se connecter au portail upload
make ssh-portal

# Detruire infrastructure
make destroy
```

## Connexion SSH aux equipes

### Methode recommandee (avec fichier ssh_config)
```bash
# Depuis le dossier keys/<team>/
ssh -F ssh_config gpu
```

### Methode alternative (commande complete)
```bash
ssh -i keys/atos/ssh_private_key.pem \
    -o ProxyCommand="ssh -i keys/atos/ssh_private_key.pem -W %h:%p root@<BASTION_IP>" \
    root@<GPU_IP>
```
