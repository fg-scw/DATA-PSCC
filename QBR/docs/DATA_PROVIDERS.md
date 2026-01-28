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
