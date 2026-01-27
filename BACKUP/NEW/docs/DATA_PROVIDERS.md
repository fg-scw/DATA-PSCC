# Hackathon HDS - Guide Fournisseurs de Données

## Vue d'ensemble

Les données patients doivent être uploadées avec chiffrement SSE-C (AES-256).
La clé de chiffrement est fournie séparément : `keys/zone1_encryption_key.txt`

---

## Méthode 1 : Portail Web (si activé)

```
URL: http://<PORTAL_IP>
Credentials: keys/<provider>/portal_credentials.txt
```

1. Ouvrir l'URL dans un navigateur
2. S'authentifier avec les credentials
3. Sélectionner la zone (Zone 1 = Patients, Zone 2 = Évaluation)
4. Glisser-déposer les fichiers

---

## Méthode 2 : rclone (recommandé)

### Installation

```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash
```

### Configuration

```bash
# Charger les credentials
source keys/<provider>/api_credentials.env

# Créer la config rclone
cat >> ~/.config/rclone/rclone.conf << EOF
[zone1]
type = s3
provider = Scaleway
access_key_id = $SCW_ACCESS_KEY
secret_access_key = $SCW_SECRET_KEY
region = fr-par
endpoint = s3.fr-par.scw.cloud
acl = private
EOF
```

### Upload

```bash
# Lire la clé de chiffrement
ENCRYPTION_KEY=$(cat keys/zone1_encryption_key.txt)

# Upload d'un fichier
rclone copy fichier.csv zone1:<BUCKET_NAME>/ \
  --s3-sse-customer-algorithm AES256 \
  --s3-sse-customer-key "$ENCRYPTION_KEY" \
  --progress

# Upload d'un dossier
rclone sync /chemin/donnees/ zone1:<BUCKET_NAME>/batch-001/ \
  --s3-sse-customer-algorithm AES256 \
  --s3-sse-customer-key "$ENCRYPTION_KEY" \
  --progress
```

---

## Méthode 3 : AWS CLI

```bash
# Charger les credentials
source keys/<provider>/api_credentials.env
export AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY

# Préparer la clé
ENCRYPTION_KEY=$(cat keys/zone1_encryption_key.txt)
KEY_MD5=$(echo -n "$ENCRYPTION_KEY" | base64 -d | openssl dgst -md5 -binary | base64)

# Upload
aws s3 cp fichier.csv s3://<BUCKET_NAME>/ \
  --endpoint-url https://s3.fr-par.scw.cloud \
  --sse-c AES256 \
  --sse-c-key "$ENCRYPTION_KEY" \
  --sse-c-key-md5 "$KEY_MD5"
```

---

## Vérification

```bash
# Lister les fichiers uploadés
rclone ls zone1:<BUCKET_NAME>/ \
  --s3-sse-customer-algorithm AES256 \
  --s3-sse-customer-key "$ENCRYPTION_KEY"
```

---

## Bonnes pratiques

1. **Ne jamais partager la clé** par email ou messagerie
2. **Organiser les fichiers** : `batch-YYYY-MM-DD/type/fichier`
3. **Vérifier après upload** avec la commande de listing
4. **Supprimer les fichiers locaux** après confirmation
