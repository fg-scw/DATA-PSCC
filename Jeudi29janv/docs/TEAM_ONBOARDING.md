# Hackathon HDS - Guide Participant

Bienvenue dans le Hackathon HDS ! Ce guide vous explique comment accéder à votre environnement de travail.

## 📦 Contenu de votre package

Vous avez reçu un dossier contenant :

```
votre-equipe/
├── ssh_private_key.pem    # Clé SSH pour accéder aux serveurs
├── api_credentials.env    # Credentials API Scaleway pour S3
├── credentials.md         # Résumé de vos accès (IPs, commandes)
├── connect-gpu.sh         # Script de connexion au GPU (recommandé)
├── connect-bastion.sh     # Script de connexion au bastion
└── README.md              # Ce fichier
```

## 🔐 Première connexion

### Prérequis

- Terminal (macOS/Linux) ou WSL2/Git Bash (Windows)
- Les fichiers credentials de votre équipe

### Connexion au GPU (méthode recommandée)

```bash
# 1. Extraire le zip
unzip votre-equipe-credentials.zip
cd votre-equipe/

# 2. Rendre le script exécutable et se connecter
chmod +x connect-gpu.sh
./connect-gpu.sh
```

C'est tout ! Le script gère automatiquement les permissions et la connexion via le bastion.

### Connexion alternative (commande manuelle)

Si le script ne fonctionne pas, utilisez la commande manuelle depuis le dossier credentials :

```bash
chmod 600 ssh_private_key.pem
ssh -i ssh_private_key.pem -o ProxyCommand="ssh -i ssh_private_key.pem -W %h:%p root@<BASTION_IP>" root@<GPU_IP>
```

Remplacez `<BASTION_IP>` et `<GPU_IP>` par les valeurs indiquées dans `credentials.md`.

## 🖥️ Votre environnement GPU

Une fois connecté, vous disposez de :

- **GPU** : NVIDIA L40S (48GB VRAM)
- **Stockage** : 125GB SSD haute performance
- **Docker** : Pré-installé avec support GPU (`nvidia-docker`)
- **OS** : Ubuntu 22.04 avec drivers NVIDIA

### Vérifier le GPU

```bash
nvidia-smi
```

## 📊 Accès aux données patients

### Configuration initiale (une seule fois)

Récupérez vos credentials API depuis le fichier `api_credentials.env` :

```bash
# Sur votre machine locale, voir le contenu
cat api_credentials.env
```

Puis sur le GPU :

```bash
# Configurer l'accès S3 avec vos credentials
./setup-s3.sh SCWXXXXXXXXXX votre-secret-key
```

### Télécharger les données

```bash
# Synchroniser les données patients
./sync-data.sh

# Les données seront dans /data/patients/
ls -la /data/patients/
```

## 📤 Soumettre vos livrables

```bash
# Uploader un fichier
./upload-livrable.sh mon_modele.tar.gz

# Uploader un dossier (zipper d'abord)
tar -czvf resultats.tar.gz ./resultats/
./upload-livrable.sh resultats.tar.gz
```

## 🐳 Utilisation de Docker avec GPU

```bash
# Lancer un conteneur avec accès GPU
docker run --gpus all -it --rm \
    -v /data:/data \
    nvidia/cuda:12.0-base \
    nvidia-smi

# Exemple avec PyTorch
docker run --gpus all -it --rm \
    -v /data:/data \
    -v $(pwd):/workspace \
    pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime \
    python train.py
```

## 🔧 Commandes utiles

```bash
# Vérifier l'espace disque
df -h

# Surveiller l'utilisation GPU
watch -n 1 nvidia-smi

# Voir les conteneurs en cours
docker ps

# Nettoyer les images Docker inutilisées
docker system prune -a
```

## ⚠️ Règles importantes

1. **Ne partagez JAMAIS** vos credentials avec d'autres équipes
2. **Les données patients** ne doivent pas quitter l'environnement GPU
3. **Soumettez régulièrement** vos livrables (ils sont horodatés)
4. **Deadline** : Consultez `credentials.md` pour la date limite

## 🆘 En cas de problème

### Le script connect-gpu.sh échoue

Vérifiez que :
1. Vous êtes bien dans le dossier contenant les credentials
2. La clé SSH a les bonnes permissions : `chmod 600 ssh_private_key.pem`
3. Les IPs dans `credentials.md` sont correctes

### Le GPU n'est pas détecté

```bash
# Recharger les modules NVIDIA
sudo modprobe nvidia
nvidia-smi
```

### Pas d'accès Internet sur le GPU

Contactez l'équipe organisatrice - c'est un problème de configuration réseau.

### Problème avec les données S3

```bash
# Recharger les credentials
source /root/.env

# Vérifier la configuration
cat /root/.env
```

## 📞 Contact support

En cas de problème technique, contactez l'équipe organisatrice via le canal dédié.

---

Bonne chance pour le hackathon ! 🚀
