# Hackathon HDS - Guide Évaluateur

Ce guide explique comment accéder aux environnements des équipes et aux livrables pour l'évaluation.

## 📦 Vos credentials

```
evaluators/
├── api_credentials.env    # Credentials API Scaleway (lecture seule)
└── portal_credentials.txt # Accès au portail web (si activé)
```

## 🌐 Accès au Portail Web

Si le portail d'upload est activé, vous pouvez y accéder pour visualiser les uploads :

```
URL: http://<PORTAL_IP>
Credentials: Voir portal_credentials.txt
```

## 📊 Accès aux buckets S3

### Configuration

```bash
# Charger les credentials
source evaluators/api_credentials.env

# Installer rclone si nécessaire
# macOS: brew install rclone
# Linux: curl https://rclone.org/install.sh | sudo bash

# Configurer rclone
cat >> ~/.config/rclone/rclone.conf << EOF
[hackathon]
type = s3
provider = Scaleway
access_key_id = $SCW_ACCESS_KEY
secret_access_key = $SCW_SECRET_KEY
region = fr-par
endpoint = s3.fr-par.scw.cloud
acl = private
EOF
```

### Accéder aux livrables

```bash
# Lire la clé de chiffrement (fournie séparément)
LIVRABLES_KEY=$(cat livrables_encryption_key.txt)

# Lister les livrables
rclone ls hackathon:<LIVRABLES_BUCKET>/ \
    --s3-sse-customer-algorithm AES256 \
    --s3-sse-customer-key "$LIVRABLES_KEY"

# Télécharger un livrable
rclone copy hackathon:<LIVRABLES_BUCKET>/20260127_143000/model.tar.gz ./ \
    --s3-sse-customer-algorithm AES256 \
    --s3-sse-customer-key "$LIVRABLES_KEY"
```

### Accéder aux données Zone 2 (évaluation)

```bash
# Lire la clé de chiffrement
ZONE2_KEY=$(cat zone2_encryption_key.txt)

# Lister les fichiers
rclone ls hackathon:<ZONE2_BUCKET>/ \
    --s3-sse-customer-algorithm AES256 \
    --s3-sse-customer-key "$ZONE2_KEY"
```

## 🔍 Accès aux projets des équipes

Vous avez un accès **lecture seule** à tous les projets d'équipes via la console Scaleway ou l'API.

### Via la Console Scaleway

1. Connectez-vous à https://console.scaleway.com
2. Sélectionnez le projet de l'équipe à évaluer
3. Naviguez vers Instances > GPU pour voir l'état

### Via l'API/CLI

```bash
# Installer le CLI Scaleway
brew install scw  # macOS
# ou
curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/scripts/get.sh | sh

# Configurer
source evaluators/api_credentials.env
scw init

# Lister les instances d'un projet
scw instance server list project-id=<PROJECT_ID>

# Voir les détails d'une instance GPU
scw instance server get <SERVER_ID>
```

## 📋 Checklist d'évaluation

Pour chaque équipe :

- [ ] Vérifier que des livrables ont été soumis
- [ ] Télécharger et extraire les livrables
- [ ] Exécuter les scripts d'évaluation sur Zone 2
- [ ] Documenter les résultats

## 🔒 Règles de sécurité

1. **Lecture seule** : Vous ne pouvez pas modifier les environnements des équipes
2. **Confidentialité** : Ne partagez pas les livrables entre équipes
3. **Données patients** : Les données Zone 1 ne vous sont pas accessibles

## 🆘 Support

Contactez l'équipe organisatrice pour toute question.
