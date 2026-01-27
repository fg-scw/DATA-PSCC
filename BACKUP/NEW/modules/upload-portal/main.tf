#===============================================================================
# UPLOAD PORTAL MODULE - VM-based
# Deploys a VM with Docker to host the upload portal
#===============================================================================

locals {
  portal_name = "${var.project_prefix}-upload-portal"
}

#-------------------------------------------------------------------------------
# Security Group
#-------------------------------------------------------------------------------
resource "scaleway_instance_security_group" "portal" {
  project_id              = var.admin_project_id
  zone                    = var.zone
  name                    = "${local.portal_name}-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true

  inbound_rule {
    action   = "accept"
    port     = 22
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    port     = 80
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    port     = 443
    protocol = "TCP"
  }
}

#-------------------------------------------------------------------------------
# Public IP
#-------------------------------------------------------------------------------
resource "scaleway_instance_ip" "portal" {
  project_id = var.admin_project_id
  zone       = var.zone
  tags       = ["hackathon", "upload-portal"]
}

#-------------------------------------------------------------------------------
# Generate provider passwords
#-------------------------------------------------------------------------------
resource "random_password" "provider_passwords" {
  for_each         = var.data_providers
  length           = 16
  special          = false
}

locals {
  provider_credentials = {
    for key, provider in var.data_providers : key => {
      username = lower(replace(replace(provider.name, " ", "-"), "&", "and"))
      password = random_password.provider_passwords[key].result
    }
  }
  
  htpasswd_content = join("\n", [
    for key, creds in local.provider_credentials : 
    "${creds.username}:${bcrypt(creds.password)}"
  ])
}

#-------------------------------------------------------------------------------
# Instance
#-------------------------------------------------------------------------------
resource "scaleway_instance_server" "portal" {
  project_id = var.admin_project_id
  zone       = var.zone
  name       = local.portal_name
  type       = var.instance_type
  image      = "ubuntu_jammy"

  ip_id             = scaleway_instance_ip.portal.id
  security_group_id = scaleway_instance_security_group.portal.id

  root_volume {
    size_in_gb  = 40
    volume_type = "sbs_volume"
    sbs_iops    = 5000
  }

  user_data = {
    cloud-init = <<-CLOUDINIT
#cloud-config
package_update: true
packages:
  - docker.io
  - docker-compose
  - apache2-utils
  - python3-pip
  - python3-venv

write_files:
  - path: /opt/upload-portal/.env
    permissions: '0600'
    content: |
      SCW_ACCESS_KEY=${var.scw_access_key}
      SCW_SECRET_KEY=${var.scw_secret_key}
      SCW_REGION=${var.region}
      ZONE1_BUCKET=${var.zone1_bucket_name}
      ZONE2_BUCKET=${var.zone2_bucket_name}
      ZONE1_KEY=${var.zone1_encryption_key}
      ZONE2_KEY=${var.zone2_encryption_key}

  - path: /opt/upload-portal/htpasswd
    permissions: '0644'
    content: |
      ${local.htpasswd_content}

  - path: /opt/upload-portal/app.py
    permissions: '0644'
    content: |
      #!/usr/bin/env python3
      import os, base64, hashlib, boto3
      from flask import Flask, request, jsonify, render_template_string
      from functools import wraps
      
      app = Flask(__name__)
      
      S3_ENDPOINT = f"https://s3.{os.environ.get('SCW_REGION', 'fr-par')}.scw.cloud"
      
      USERS = {}
      try:
          with open('/opt/upload-portal/htpasswd') as f:
              for line in f:
                  if ':' in line:
                      u, p = line.strip().split(':', 1)
                      USERS[u] = p
      except: pass
      
      def check_auth(u, p):
          import bcrypt
          if u in USERS:
              return bcrypt.checkpw(p.encode(), USERS[u].encode())
          return False
      
      def auth_required(f):
          @wraps(f)
          def decorated(*args, **kwargs):
              auth = request.authorization
              if not auth or not check_auth(auth.username, auth.password):
                  return ('Auth required', 401, {'WWW-Authenticate': 'Basic realm="Upload"'})
              return f(*args, **kwargs)
          return decorated
      
      def get_s3():
          return boto3.client('s3',
              endpoint_url=S3_ENDPOINT,
              aws_access_key_id=os.environ['SCW_ACCESS_KEY'],
              aws_secret_access_key=os.environ['SCW_SECRET_KEY'])
      
      def sse_key(zone):
          k = os.environ.get(f'{zone.upper()}_KEY', '')
          md5 = base64.b64encode(hashlib.md5(base64.b64decode(k)).digest()).decode()
          return k, md5
      
      HTML = '''<!DOCTYPE html><html><head><title>Upload HDS</title>
      <style>body{font-family:sans-serif;max-width:800px;margin:50px auto;padding:20px}
      .zone{display:inline-block;padding:20px;margin:10px;border:2px solid #ccc;border-radius:8px;cursor:pointer}
      .zone.active{border-color:#007bff;background:#e7f1ff}
      .drop{border:2px dashed #ccc;padding:60px;text-align:center;margin:20px 0;border-radius:8px}
      .drop.over{background:#f0f0f0}button{padding:10px 20px;background:#007bff;color:#fff;border:none;border-radius:4px;cursor:pointer}</style></head>
      <body><h1>Upload HDS</h1><p>User: <b>{{ user }}</b></p>
      <div><span class="zone active" onclick="setZone('zone1')">Zone 1 - Patients</span>
      <span class="zone" onclick="setZone('zone2')">Zone 2 - Evaluation</span></div>
      <div class="drop" id="drop">Drop files here or click<input type="file" id="file" multiple style="display:none"></div>
      <div id="status"></div>
      <script>
      let zone='zone1';
      function setZone(z){zone=z;document.querySelectorAll('.zone').forEach(e=>e.classList.remove('active'));event.target.classList.add('active')}
      const drop=document.getElementById('drop'),file=document.getElementById('file'),status=document.getElementById('status');
      drop.onclick=()=>file.click();
      drop.ondragover=e=>{e.preventDefault();drop.classList.add('over')};
      drop.ondragleave=()=>drop.classList.remove('over');
      drop.ondrop=e=>{e.preventDefault();drop.classList.remove('over');upload(e.dataTransfer.files)};
      file.onchange=()=>upload(file.files);
      async function upload(files){for(let f of files){
        status.innerHTML+=`<p>Uploading $${f.name}...</p>`;
        let fd=new FormData();fd.append('file',f);
        let r=await fetch('/upload/'+zone,{method:'POST',body:fd});
        let j=await r.json();
        status.innerHTML+=`<p>$${j.success?"OK":"ERR"} $${f.name}: $${j.message||j.error}</p>`;
      }}
      </script></body></html>'''
      
      @app.route('/')
      @auth_required
      def index():
          return render_template_string(HTML, user=request.authorization.username)
      
      @app.route('/upload/<zone>', methods=['POST'])
      @auth_required
      def upload(zone):
          if 'file' not in request.files:
              return jsonify({'error': 'No file'}), 400
          f = request.files['file']
          bucket = os.environ.get(f'{zone.upper()}_BUCKET')
          if not bucket:
              return jsonify({'error': 'Invalid zone'}), 400
          key, md5 = sse_key(zone)
          try:
              s3 = get_s3()
              s3.put_object(Bucket=bucket, Key=f'uploads/{request.authorization.username}/{f.filename}',
                  Body=f.read(), SSECustomerAlgorithm='AES256', SSECustomerKey=key, SSECustomerKeyMD5=md5)
              return jsonify({'success': True, 'message': 'Uploaded'})
          except Exception as e:
              return jsonify({'error': str(e)}), 500
      
      @app.route('/health')
      def health():
          return 'OK'
      
      if __name__ == '__main__':
          app.run(host='0.0.0.0', port=5000)

  - path: /opt/upload-portal/requirements.txt
    content: |
      flask
      boto3
      bcrypt
      gunicorn

  - path: /etc/systemd/system/upload-portal.service
    content: |
      [Unit]
      Description=Upload Portal
      After=network.target
      
      [Service]
      Type=simple
      User=root
      WorkingDirectory=/opt/upload-portal
      EnvironmentFile=/opt/upload-portal/.env
      ExecStart=/opt/upload-portal/venv/bin/gunicorn -b 0.0.0.0:80 -w 2 app:app
      Restart=always
      
      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p /opt/upload-portal
  - cd /opt/upload-portal
  - python3 -m venv venv
  - /opt/upload-portal/venv/bin/pip install -r /opt/upload-portal/requirements.txt
  - systemctl daemon-reload
  - systemctl enable upload-portal
  - systemctl start upload-portal
CLOUDINIT
  }

  tags = ["hackathon", "upload-portal"]

  lifecycle {
    ignore_changes = [user_data]
  }
}

#-------------------------------------------------------------------------------
# Store provider credentials
#-------------------------------------------------------------------------------
resource "local_sensitive_file" "provider_credentials" {
  for_each        = var.data_providers
  filename        = "${path.root}/keys/${lower(replace(replace(each.value.name, " ", "-"), "&", "and"))}/portal_credentials.txt"
  file_permission = "0600"
  content         = <<-EOT
# Upload Portal Credentials - ${each.value.name}

URL: http://${scaleway_instance_ip.portal.address}
Username: ${local.provider_credentials[each.key].username}
Password: ${local.provider_credentials[each.key].password}
EOT
}
