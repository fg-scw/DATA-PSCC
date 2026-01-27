# Hackathon HDS - Infrastructure Terraform

Infrastructure cloud sécurisée pour Data Challenge avec données de santé (HDS).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PROJET ADMIN (stockage global)                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐  │
│  │   Bucket Zone 1     │    │   Bucket Zone 2     │    │  Bucket Livrables   │  │
│  │  (données patients) │    │   (évaluation)      │    │  (Object Lock 1an)  │  │
│  │  SSE-C chiffré      │    │  SSE-C chiffré      │    │  SSE-C chiffré      │  │
│  └─────────────────────┘    └─────────────────────┘    └─────────────────────┘  │
│                                                                                  │
│  Accès: PSCC (full), IPP (read), IGR (RW), Curie (RW), Participants (RO Zone1)  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                      PROJET EQUIPE (x8 - un par participant)                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────── VPC + Private Network ─────────────────────────┐ │
│  │   ┌─────────────────────┐         ┌─────────────────────────────────────┐  │ │
│  │   │   Bastion/NAT       │         │         VM GPU L40S-1-48G           │  │ │
│  │   │   PRO2-XS           │◄───────►│         200GB SBS                   │  │ │
│  │   │   + Flexible IP     │   PN    │         ubuntu_jammy_gpu_os_12      │  │ │
│  │   └─────────────────────┘         └─────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Prérequis

- Terraform >= 1.5.0
- Scaleway CLI (optionnel, pour debug)
- rclone (pour les scripts d'upload)
- jq (pour les helpers Makefile)

## Configuration

### 1. Créer un profil Scaleway dédié

Pour isoler ce déploiement de vos autres projets Scaleway, créez un profil dédié dans `~/.config/scw/config.yaml` :

```yaml
profiles:
  hackathon-hds:
    access_key: SCWXXXXXXXXXXXXXXXXX
    secret_key: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    default_organization_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    default_region: fr-par
    default_zone: fr-par-2
```

### 2. Configurer le déploiement

```bash
cp terraform.tfvars.example terraform.tfvars
```

Éditer `terraform.tfvars` avec:
- `scw_profile`: Nom du profil Scaleway à utiliser
- `organization_id`: ID de l'organisation Scaleway
- `bucket_prefix`: Préfixe unique pour les buckets S3
- `teams`: Liste des équipes participantes avec leurs membres
- `admins`, `evaluators`, `data_providers`: Accès administratifs

## Déploiement

### Mode Dry-Run (test sans invitations)

```bash
make init
make apply-dry
```

Ce mode déploie toute l'infrastructure SANS créer les utilisateurs IAM, donc aucune invitation n'est envoyée par email.

### Mode Production (avec invitations)

```bash
make apply-prod
```

⚠️ Ce mode envoie des invitations par email à tous les utilisateurs configurés.

## Structure des credentials

Après déploiement, les credentials sont générés dans `keys/`:

```
keys/
├── zone1_encryption_key.txt      # Clé SSE-C Zone 1
├── zone2_encryption_key.txt      # Clé SSE-C Zone 2
├── livrables_encryption_key.txt  # Clé SSE-C Livrables
├── admin/
│   └── api_credentials.env       # Credentials admin
├── institut-curie/
│   └── api_credentials.env       # Credentials IGR
├── thales-services-numeriques/
│   ├── ssh_private_key.pem       # Clé SSH équipe
│   ├── ssh_public_key.pub
│   ├── credentials.md            # Documentation
│   └── api_credentials.env       # Credentials API
└── ...
```

## Workflow Data Challenge

### 1. Avant le challenge

**Fournisseurs de données (IGR, Curie):**
```bash
make upload-zone1 DIR=/chemin/vers/donnees/patients
make upload-zone2 DIR=/chemin/vers/donnees/evaluation
```

**Organisateurs (PSCC):**
```bash
make package-credentials
# Distribuer dist/*.zip aux équipes
```

### 2. Pendant le challenge

**Participants:**
```bash
# Se connecter à la VM GPU
ssh -i ssh_private_key.pem -J root@<BASTION_IP> root@<GPU_PRIVATE_IP>

# Configuration initiale (une seule fois)
./setup-s3.sh <ACCESS_KEY> <SECRET_KEY>

# Synchroniser les données patients
sync-data.sh

# Soumettre un livrable
upload-livrable.sh mon-code.zip
```

### 3. Fin du challenge

- Les API keys des participants expirent automatiquement
- Les livrables restent accessibles 1 an (Object Lock COMPLIANCE)

## Sécurité

- **Chiffrement SSE-C** : Toutes les données sont chiffrées avec des clés AES-256
- **Réseau isolé** : Les VMs GPU n'ont pas d'IP publique
- **IAM granulaire** : Policies par rôle et par projet
- **Expiration automatique** : API keys avec date d'expiration

## Commandes utiles

```bash
make help           # Afficher l'aide
make show-access    # Voir les informations d'accès
make show-teams     # Lister les commandes SSH
make show-mode      # Voir le mode actuel (dry-run/prod)
make destroy        # Détruire l'infrastructure
```

## Support

En cas de problème technique, contacter l'équipe PSCC.
