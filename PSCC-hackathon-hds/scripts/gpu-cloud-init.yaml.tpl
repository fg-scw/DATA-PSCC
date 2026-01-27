README.md
    permissions: '0644'
    content: |
      # Hackathon HDS - ${team_name}
      
      ## Configuration initiale
      
      Avant de pouvoir accéder aux données, vous devez configurer vos credentials S3:
      
      ```bash
      ./setup-s3.sh <VOTRE_ACCESS_KEY> <VOTRE_SECRET_KEY>
      ```
      
      Les credentials sont fournis dans le fichier `api_credentials.env` 
      de votre dossier de credentials.
      
      ## Accès aux données patients
      
      ### Option 1: Copie locale (recommandé)
      ```bash
      sync-data.sh
      ls /data/patients
      ```
      
      ### Option 2: Montage S3 (lecture seule)
      ```bash
      mount-s3.sh
      ls /mnt/zone1
      ```
      
      ## Soumettre un livrable
      
      ```bash
      # Créez une archive de votre code
      zip -r mon-livrable.zip mon-code/
      
      # Uploadez
      upload-livrable.sh mon-livrable.zip
      ```
      
      ## Informations importantes
      
      - GPU: ${gpu_type}
      - Date limite: ${challenge_end_date}
      - Clé de chiffrement SSE-C: `${encryption_key_base64}`
      
      ## Support
      
      En cas de problème technique, contactez l'équipe PSCC.

runcmd:
  # Add user to docker group
  - usermod -aG docker root
  
  # Enable docker
  - systemctl enable docker
  - systemctl start docker
  
  # Apply netplan for default route
  - netplan apply || true
  
  # Create data directory
  - mkdir -p /data/patients
  - chmod 755 /data
  
  # Wait for network
  - sleep 10
  
  # Verify GPU
  - nvidia-smi || echo "GPU not yet available - will be ready after reboot"

final_message: "GPU Instance ready after $UPTIME seconds - Run ./setup-s3.sh to configure S3 access"
