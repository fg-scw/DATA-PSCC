#===============================================================================
# UPLOAD PORTAL MODULE - VM-based
# Deploys a VM with Docker to host the upload portal
#===============================================================================

locals {
  portal_name = "${var.project_prefix}-upload-portal"
}

#-------------------------------------------------------------------------------
# SSH Key for Upload Portal
#-------------------------------------------------------------------------------
resource "tls_private_key" "portal" {
  algorithm = "ED25519"
}

resource "scaleway_iam_ssh_key" "portal" {
  name       = "upload-portal-ssh-key"
  public_key = tls_private_key.portal.public_key_openssh
  project_id = var.admin_project_id
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
      import os, base64, hashlib, boto3, traceback
      from datetime import datetime
      from flask import Flask, request, jsonify, render_template_string
      from functools import wraps
      from botocore.exceptions import ClientError
      
      app = Flask(__name__)
      
      S3_ENDPOINT = f"https://s3.{os.environ.get('SCW_REGION', 'fr-par')}.scw.cloud"
      
      USERS = {}
      try:
          with open('/opt/upload-portal/htpasswd') as f:
              for line in f:
                  if ':' in line:
                      u, p = line.strip().split(':', 1)
                      USERS[u] = p
      except Exception as e:
          print(f"Error loading htpasswd: {e}")
      
      def check_auth(u, p):
          import bcrypt
          if u in USERS:
              try:
                  return bcrypt.checkpw(p.encode(), USERS[u].encode())
              except Exception as e:
                  print(f"Auth error: {e}")
                  return False
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
      
      def sse_params(zone):
          """Get SSE-C parameters for a zone"""
          key_b64 = os.environ.get(f'{zone.upper()}_KEY', '')
          if not key_b64:
              return None
          key_raw = base64.b64decode(key_b64)
          key_md5 = base64.b64encode(hashlib.md5(key_raw).digest()).decode()
          return {
              'SSECustomerAlgorithm': 'AES256',
              'SSECustomerKey': key_b64,
              'SSECustomerKeyMD5': key_md5
          }
      
      def format_size(size):
          """Format file size in human readable format"""
          for unit in ['B', 'KB', 'MB', 'GB']:
              if size < 1024:
                  return f"{size:.1f} {unit}"
              size /= 1024
          return f"{size:.1f} TB"
      
      HTML = '''<!DOCTYPE html><html><head><title>Upload HDS</title>
      <style>
      body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;max-width:1100px;margin:30px auto;padding:20px;background:#f0f2f5}
      .container{background:white;padding:30px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.1);margin-bottom:20px}
      h1{color:#1a1a2e;margin-bottom:5px}
      h2{color:#16213e;margin-top:0;font-size:1.2em;border-bottom:2px solid #e0e0e0;padding-bottom:10px}
      .user-info{color:#666;margin-bottom:20px;font-size:0.95em}
      .tabs{display:flex;gap:10px;margin-bottom:20px}
      .tab{padding:12px 24px;background:#e8e8e8;border:none;border-radius:8px;cursor:pointer;font-size:15px;transition:all 0.2s}
      .tab:hover{background:#d0d0d0}
      .tab.active{background:#007bff;color:white}
      .zone{display:inline-block;padding:12px 20px;margin:5px;border:2px solid #ddd;border-radius:8px;cursor:pointer;transition:all 0.2s}
      .zone:hover{border-color:#007bff;background:#f8f9fa}
      .zone.active{border-color:#007bff;background:#e7f1ff}
      .drop{border:3px dashed #ccc;padding:50px;text-align:center;margin:20px 0;border-radius:8px;transition:all 0.2s;background:#fafafa}
      .drop:hover{border-color:#007bff;background:#f0f7ff}
      .drop.over{background:#e7f1ff;border-color:#007bff}
      .btn{padding:10px 20px;background:#007bff;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:14px;margin:5px}
      .btn:hover{background:#0056b3}
      .btn-sm{padding:6px 12px;font-size:12px}
      .btn-danger{background:#dc3545}
      .btn-danger:hover{background:#c82333}
      #status{margin-top:15px;padding:15px;background:#f8f9fa;border-radius:6px;max-height:200px;overflow-y:auto;font-size:13px}
      .success{color:#28a745}
      .error{color:#dc3545}
      .info{color:#17a2b8}
      .file-list{width:100%;border-collapse:collapse;margin-top:15px;font-size:14px}
      .file-list th,.file-list td{padding:10px 12px;text-align:left;border-bottom:1px solid #eee}
      .file-list th{background:#f8f9fa;font-weight:600;color:#333}
      .file-list tr:hover{background:#f8f9fa}
      .file-icon{margin-right:8px}
      .empty-state{text-align:center;padding:40px;color:#888}
      .refresh-btn{float:right;margin-top:-5px}
      .loading{text-align:center;padding:30px;color:#666}
      .panel{display:none}
      .panel.active{display:block}
      </style></head>
      <body>
      <div class="container">
        <h1>🏥 Hackathon PSCC - Data Portal</h1>
        <p class="user-info">Connected as: <strong>{{ user }}</strong></p>
        
        <div class="tabs">
          <button class="tab active" onclick="showPanel('upload')">📤 Upload</button>
          <button class="tab" onclick="showPanel('browse')">📁 Browse Files</button>
        </div>
        
        <div id="upload-panel" class="panel active">
          <h2>Upload Files</h2>
          <p>Select destination zone:</p>
          <div>
            <span class="zone active" data-zone="zone1" onclick="setZone('zone1', this)">📁 Zone 1 - Patient Data</span>
            <span class="zone" data-zone="zone2" onclick="setZone('zone2', this)">📊 Zone 2 - Evaluation</span>
          </div>
          
          <div class="drop" id="drop">
            <p style="font-size:18px;margin:0">📤 Drop files here or click to select</p>
            <p style="color:#888;margin:10px 0 0 0">Files will be uploaded to: uploads/{{ user }}/</p>
            <input type="file" id="file" multiple style="display:none">
          </div>
          
          <div id="status"></div>
        </div>
        
        <div id="browse-panel" class="panel">
          <h2>Browse Files <button class="btn btn-sm refresh-btn" onclick="loadFiles()">🔄 Refresh</button></h2>
          <p>Select zone to browse:</p>
          <div>
            <span class="zone active" data-zone="zone1" onclick="setBrowseZone('zone1', this)">📁 Zone 1 - Patient Data</span>
            <span class="zone" data-zone="zone2" onclick="setBrowseZone('zone2', this)">📊 Zone 2 - Evaluation</span>
          </div>
          <div id="file-list-container">
            <div class="loading">Select a zone and click Refresh to load files</div>
          </div>
        </div>
      </div>
      
      <script>
      let zone = 'zone1';
      let browseZone = 'zone1';
      
      function showPanel(name) {
        document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.getElementById(name + '-panel').classList.add('active');
        event.target.classList.add('active');
        if (name === 'browse') loadFiles();
      }
      
      function setZone(z, el) {
        zone = z;
        document.querySelectorAll('#upload-panel .zone').forEach(e => e.classList.remove('active'));
        el.classList.add('active');
        addStatus('info', 'Upload zone: ' + z);
      }
      
      function setBrowseZone(z, el) {
        browseZone = z;
        document.querySelectorAll('#browse-panel .zone').forEach(e => e.classList.remove('active'));
        el.classList.add('active');
        loadFiles();
      }
      
      function addStatus(type, msg) {
        const status = document.getElementById('status');
        const time = new Date().toLocaleTimeString();
        status.innerHTML = '<p class="' + type + '">[' + time + '] ' + msg + '</p>' + status.innerHTML;
      }
      
      async function loadFiles() {
        const container = document.getElementById('file-list-container');
        container.innerHTML = '<div class="loading">Loading files...</div>';
        
        try {
          const r = await fetch('/list/' + browseZone);
          const data = await r.json();
          
          if (!data.success) {
            container.innerHTML = '<div class="error">Error: ' + data.error + '</div>';
            return;
          }
          
          if (data.files.length === 0) {
            container.innerHTML = '<div class="empty-state">📭 No files in this zone yet</div>';
            return;
          }
          
          let html = '<table class="file-list"><thead><tr><th>Name</th><th>Size</th><th>Last Modified</th></tr></thead><tbody>';
          data.files.forEach(f => {
            const icon = f.key.endsWith('/') ? '📁' : '📄';
            html += '<tr><td><span class="file-icon">' + icon + '</span>' + f.key + '</td>';
            html += '<td>' + f.size + '</td>';
            html += '<td>' + f.modified + '</td></tr>';
          });
          html += '</tbody></table>';
          container.innerHTML = html;
        } catch (e) {
          container.innerHTML = '<div class="error">Failed to load files: ' + e.message + '</div>';
        }
      }
      
      const drop = document.getElementById('drop');
      const fileInput = document.getElementById('file');
      
      drop.onclick = () => fileInput.click();
      drop.ondragover = e => { e.preventDefault(); drop.classList.add('over'); };
      drop.ondragleave = () => drop.classList.remove('over');
      drop.ondrop = e => { e.preventDefault(); drop.classList.remove('over'); upload(e.dataTransfer.files); };
      fileInput.onchange = () => upload(fileInput.files);
      
      async function upload(files) {
        for (let f of files) {
          addStatus('info', 'Uploading ' + f.name + ' to ' + zone + '...');
          let fd = new FormData();
          fd.append('file', f);
          try {
            let r = await fetch('/upload/' + zone, { method: 'POST', body: fd });
            let j = await r.json();
            if (j.success) {
              addStatus('success', '✅ ' + f.name + ': ' + j.message);
            } else {
              addStatus('error', '❌ ' + f.name + ': ' + j.error);
            }
          } catch (e) {
            addStatus('error', '❌ ' + f.name + ': Network error - ' + e.message);
          }
        }
      }
      
      addStatus('info', 'Ready to upload files');
      </script>
      </body></html>'''
      
      @app.route('/')
      @auth_required
      def index():
          return render_template_string(HTML, user=request.authorization.username)
      
      @app.route('/list/<zone>')
      @auth_required
      def list_files(zone):
          bucket = os.environ.get(f'{zone.upper()}_BUCKET')
          if not bucket:
              return jsonify({'success': False, 'error': f'Invalid zone: {zone}'}), 400
          
          try:
              s3 = get_s3()
              response = s3.list_objects_v2(Bucket=bucket, MaxKeys=500)
              
              files = []
              for obj in response.get('Contents', []):
                  files.append({
                      'key': obj['Key'],
                      'size': format_size(obj['Size']),
                      'modified': obj['LastModified'].strftime('%Y-%m-%d %H:%M')
                  })
              
              return jsonify({
                  'success': True,
                  'files': files,
                  'bucket': bucket
              })
          except ClientError as e:
              error_code = e.response.get('Error', {}).get('Code', 'Unknown')
              return jsonify({'success': False, 'error': f'S3 Error: {error_code}'}), 500
      
      @app.route('/upload/<zone>', methods=['POST'])
      @auth_required
      def upload(zone):
          if 'file' not in request.files:
              return jsonify({'success': False, 'error': 'No file provided'}), 400
          
          f = request.files['file']
          if not f.filename:
              return jsonify({'success': False, 'error': 'Empty filename'}), 400
          
          bucket = os.environ.get(f'{zone.upper()}_BUCKET')
          if not bucket:
              return jsonify({'success': False, 'error': f'Invalid zone: {zone}'}), 400
          
          sse = sse_params(zone)
          if not sse:
              return jsonify({'success': False, 'error': f'No encryption key for {zone}'}), 500
          
          username = request.authorization.username
          object_key = f'uploads/{username}/{f.filename}'
          
          try:
              s3 = get_s3()
              s3.put_object(
                  Bucket=bucket,
                  Key=object_key,
                  Body=f.read(),
                  **sse
              )
              return jsonify({
                  'success': True,
                  'message': f'Uploaded to {bucket}/{object_key}'
              })
          except ClientError as e:
              error_code = e.response.get('Error', {}).get('Code', 'Unknown')
              error_msg = e.response.get('Error', {}).get('Message', str(e))
              app.logger.error(f"S3 ClientError: {error_code} - {error_msg}")
              return jsonify({
                  'success': False,
                  'error': f'S3 Error ({error_code}): {error_msg}'
              }), 500
          except Exception as e:
              app.logger.error(f"Upload error: {traceback.format_exc()}")
              return jsonify({
                  'success': False,
                  'error': f'Upload failed: {str(e)}'
              }), 500
      
      @app.route('/health')
      def health():
          return jsonify({
              'status': 'OK',
              'zone1_bucket': os.environ.get('ZONE1_BUCKET', 'NOT SET'),
              'zone2_bucket': os.environ.get('ZONE2_BUCKET', 'NOT SET'),
              'region': os.environ.get('SCW_REGION', 'NOT SET')
          })
      
      @app.route('/debug')
      @auth_required
      def debug():
          """Debug endpoint to test S3 connectivity"""
          results = {}
          s3 = get_s3()
          
          for zone in ['zone1', 'zone2']:
              bucket = os.environ.get(f'{zone.upper()}_BUCKET')
              if bucket:
                  try:
                      # Try to list bucket (doesn't need SSE)
                      s3.head_bucket(Bucket=bucket)
                      results[zone] = {'bucket': bucket, 'status': 'accessible'}
                  except ClientError as e:
                      error_code = e.response.get('Error', {}).get('Code', 'Unknown')
                      results[zone] = {'bucket': bucket, 'status': 'error', 'code': error_code}
              else:
                  results[zone] = {'bucket': None, 'status': 'not configured'}
          
          return jsonify(results)
      
      if __name__ == '__main__':
          app.run(host='0.0.0.0', port=5000, debug=True)

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
      ExecStart=/opt/upload-portal/venv/bin/gunicorn -b 0.0.0.0:80 -w 2 --timeout 120 app:app
      Restart=always
      
      [Install]
      WantedBy=multi-user.target

  - path: /etc/motd
    content: |
      ==============================================================
        HACKATHON HDS - UPLOAD PORTAL
      ==============================================================
        Service: systemctl status upload-portal
        Logs: journalctl -u upload-portal -f
        Debug: curl http://localhost/health
      ==============================================================

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

  depends_on = [scaleway_iam_ssh_key.portal]

  lifecycle {
    ignore_changes = [user_data]
  }
}

#-------------------------------------------------------------------------------
# Store SSH key locally
#-------------------------------------------------------------------------------
resource "local_sensitive_file" "portal_ssh_key" {
  content         = tls_private_key.portal.private_key_openssh
  filename        = "${path.root}/keys/upload-portal/ssh_private_key.pem"
  file_permission = "0600"
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

## Debug endpoints
Health check: curl http://${scaleway_instance_ip.portal.address}/health
Debug S3: curl -u ${local.provider_credentials[each.key].username}:${local.provider_credentials[each.key].password} http://${scaleway_instance_ip.portal.address}/debug
EOT
}

resource "local_file" "portal_access_info" {
  filename        = "${path.root}/keys/upload-portal/access.md"
  file_permission = "0644"
  content         = <<-EOT
# Upload Portal - Admin Access

## SSH Access
```bash
ssh -i ssh_private_key.pem root@${scaleway_instance_ip.portal.address}
```

## Service Management
```bash
# Check status
systemctl status upload-portal

# View logs
journalctl -u upload-portal -f

# Restart service
systemctl restart upload-portal
```

## Debug
```bash
# Health check
curl http://localhost/health

# Check environment
cat /opt/upload-portal/.env

# Test S3 access manually
source /opt/upload-portal/.env
aws s3 ls s3://$ZONE1_BUCKET --endpoint-url https://s3.$SCW_REGION.scw.cloud
```
EOT
}
