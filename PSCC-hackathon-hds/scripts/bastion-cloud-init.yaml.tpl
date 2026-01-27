#cloud-config
# Bastion / NAT Gateway cloud-init configuration
# This instance serves as SSH jump host and NAT gateway for GPU instances

package_update: true
package_upgrade: true

packages:
  - iptables
  - iptables-persistent
  - fail2ban
  - ufw
  - htop
  - tmux
  - net-tools

write_files:
  # Script de configuration NAT
  - path: /etc/network/if-up.d/nat-setup
    permissions: '0755'
    content: |
      #!/bin/bash
      # NAT configuration for GPU instances
      
      # Get the private network interface (ens6 or similar)
      PRIVATE_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^ens[0-9]+$' | tail -1)
      PUBLIC_IF="ens2"
      
      if [ -z "$PRIVATE_IF" ]; then
        echo "Private interface not found, skipping NAT setup"
        exit 0
      fi
      
      # Enable IP forwarding
      echo 1 > /proc/sys/net/ipv4/ip_forward
      
      # Clear existing NAT rules
      iptables -t nat -F POSTROUTING
      
      # Setup NAT masquerade
      iptables -t nat -A POSTROUTING -o $PUBLIC_IF -j MASQUERADE
      
      # Allow forwarding
      iptables -A FORWARD -i $PRIVATE_IF -o $PUBLIC_IF -j ACCEPT
      iptables -A FORWARD -i $PUBLIC_IF -o $PRIVATE_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
      
      # Save rules
      iptables-save > /etc/iptables/rules.v4
      
      echo "NAT configured: $PRIVATE_IF -> $PUBLIC_IF"

  # Configuration sysctl pour le forwarding
  - path: /etc/sysctl.d/99-nat.conf
    content: |
      net.ipv4.ip_forward = 1
      net.ipv4.conf.all.forwarding = 1
      net.ipv6.conf.all.forwarding = 0

  # Configuration fail2ban
  - path: /etc/fail2ban/jail.local
    content: |
      [DEFAULT]
      bantime = 3600
      findtime = 600
      maxretry = 3
      
      [sshd]
      enabled = true
      port = ${ssh_port}
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3

  # Message of the day
  - path: /etc/motd
    content: |
      ╔═══════════════════════════════════════════════════════════════════╗
      ║                    HACKATHON HDS - BASTION                        ║
      ║                                                                   ║
      ║  Équipe: ${team_name}
      ║                                                                   ║
      ║  Pour accéder à la VM GPU:                                        ║
      ║    ssh root@${gpu_private_ip}
      ║                                                                   ║
      ║  Ce serveur sert de passerelle NAT pour la VM GPU.                ║
      ║  Ne pas modifier la configuration réseau.                         ║
      ╚═══════════════════════════════════════════════════════════════════╝

  # Script de healthcheck
  - path: /usr/local/bin/healthcheck.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Check NAT is working
      if iptables -t nat -L POSTROUTING -n | grep -q MASQUERADE; then
        echo "NAT: OK"
      else
        echo "NAT: FAILED"
        /etc/network/if-up.d/nat-setup
      fi
      
      # Check GPU instance connectivity
      if ping -c 1 -W 2 ${gpu_private_ip} > /dev/null 2>&1; then
        echo "GPU Instance: REACHABLE"
      else
        echo "GPU Instance: UNREACHABLE"
      fi

runcmd:
  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-nat.conf
  
  # Configure SSH
  - sed -i 's/#Port 22/Port ${ssh_port}/' /etc/ssh/sshd_config
  - sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  - sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  
  # Start fail2ban
  - systemctl enable fail2ban
  - systemctl start fail2ban
  
  # Wait for private network interface to be up
  - sleep 10
  
  # Setup NAT
  - /etc/network/if-up.d/nat-setup
  
  # Save iptables rules
  - netfilter-persistent save

final_message: "Bastion ready after $UPTIME seconds"
