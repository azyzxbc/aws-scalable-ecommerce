#!/bin/bash
# =============================================================================
# EC2 User Data Bootstrap Script
# Project: Scalable E-Commerce Web Application on AWS
# Author: Aziz Benchikh
#
# This script runs automatically when an EC2 instance launches via the
# Auto Scaling Group. It:
#   1. Updates the system
#   2. Installs Nginx web server
#   3. Retrieves DB credentials from Secrets Manager (no hardcoded passwords)
#   4. Deploys a sample e-commerce product catalog HTML page
#   5. Creates a /health endpoint for ALB health checks
#   6. Installs and starts the CloudWatch agent
# =============================================================================

set -ex  # Exit on error, print each command

# ---- Variables (injected by CloudFormation) ----
DB_SECRET_ARN="${DBSecretArn}"
DB_HOST="${DBEndpoint}"
AWS_REGION="${AWS::Region}"
ENV_NAME="${EnvironmentName}"

# ---- 1. System Update ----
echo "=== Updating system packages ==="
dnf update -y

# ---- 2. Install dependencies ----
echo "=== Installing Nginx, Python3, AWS CLI ==="
dnf install -y nginx python3 python3-pip awscli amazon-cloudwatch-agent

# ---- 3. Retrieve DB credentials from Secrets Manager ----
echo "=== Fetching DB credentials from Secrets Manager ==="
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# Store in /etc/environment (not logs) — never echo DB_PASS
echo "DB_HOST=$DB_HOST" >> /etc/environment
echo "DB_USER=$DB_USER" >> /etc/environment
echo "DB_PORT=3306"     >> /etc/environment
echo "APP_ENV=production" >> /etc/environment

# ---- 4. Get instance metadata (for display on page) ----
INSTANCE_ID=$(curl -s --max-time 3 \
  http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
AVAILABILITY_ZONE=$(curl -s --max-time 3 \
  http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
INSTANCE_TYPE=$(curl -s --max-time 3 \
  http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")

# ---- 5. Create web root directory ----
mkdir -p /usr/share/nginx/html/static
mkdir -p /var/log/ecommerce

# ---- 6. Deploy e-commerce HTML page ----
echo "=== Deploying product catalog HTML ==="
cat > /usr/share/nginx/html/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="ShopAWS - A scalable e-commerce application deployed on AWS with ALB, ASG, and RDS Multi-AZ.">
  <title>ShopAWS – Scalable E-Commerce on AWS</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    :root {
      --primary: #0ea5e9;
      --primary-dark: #0284c7;
      --bg: #0f172a;
      --surface: #1e293b;
      --border: #334155;
      --text: #e2e8f0;
      --muted: #94a3b8;
      --success: #10b981;
      --warning: #f59e0b;
    }
    body { font-family: 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); }

    /* ---- Header ---- */
    header {
      background: linear-gradient(135deg, #1e3a5f 0%, #0ea5e9 100%);
      padding: 2rem; text-align: center;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    }
    header h1 { font-size: 2.5rem; font-weight: 800; color: #fff; letter-spacing: -1px; }
    header p { color: #bae6fd; margin-top: 0.4rem; font-size: 1rem; }
    .badge {
      display: inline-flex; align-items: center; gap: 0.4rem;
      background: rgba(255,255,255,0.15); backdrop-filter: blur(8px);
      color: #fff; padding: 0.3rem 0.9rem; border-radius: 2rem;
      font-size: 0.8rem; margin-top: 0.8rem; border: 1px solid rgba(255,255,255,0.2);
    }

    /* ---- Infra Info Bar ---- */
    .infra-bar {
      background: var(--surface); border-bottom: 1px solid var(--border);
      padding: 0.6rem 2rem; display: flex; gap: 2rem; font-size: 0.8rem;
      color: var(--muted); flex-wrap: wrap; justify-content: center;
    }
    .infra-bar span { display: flex; align-items: center; gap: 0.4rem; }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--success); animation: pulse 2s infinite; }
    @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }

    /* ---- Nav ---- */
    nav {
      background: var(--surface); padding: 1rem 2rem;
      display: flex; gap: 1.5rem; align-items: center;
      border-bottom: 1px solid var(--border);
    }
    nav a { color: var(--muted); text-decoration: none; font-size: 0.9rem; transition: color 0.2s; }
    nav a:hover { color: var(--primary); }
    .cart-btn {
      margin-left: auto; background: var(--primary); color: #fff;
      padding: 0.5rem 1.2rem; border-radius: 0.5rem; font-size: 0.9rem;
      text-decoration: none; transition: background 0.2s;
    }
    .cart-btn:hover { background: var(--primary-dark); color: #fff; }

    /* ---- Products Grid ---- */
    .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
    h2 { font-size: 1.5rem; margin-bottom: 1.5rem; color: var(--text); }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 1.5rem;
    }
    .card {
      background: var(--surface); border-radius: 1rem;
      border: 1px solid var(--border); overflow: hidden;
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .card:hover { transform: translateY(-6px); box-shadow: 0 12px 30px rgba(0,0,0,0.5); }
    .card-img {
      height: 200px; display: flex; align-items: center;
      justify-content: center; font-size: 5rem;
    }
    .card-body { padding: 1.2rem; }
    .card-body h3 { font-size: 1rem; color: var(--text); margin-bottom: 0.3rem; }
    .card-body .category { font-size: 0.75rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
    .card-body .price { font-size: 1.5rem; font-weight: 700; color: var(--primary); margin: 0.6rem 0; }
    .card-body .original { font-size: 0.9rem; color: var(--muted); text-decoration: line-through; margin-left: 0.4rem; }
    .card-body p { font-size: 0.85rem; color: var(--muted); margin-bottom: 1rem; line-height: 1.5; }
    .btn-add {
      display: block; width: 100%; background: var(--primary); color: #fff;
      border: none; padding: 0.75rem; border-radius: 0.5rem; cursor: pointer;
      font-size: 0.95rem; font-weight: 600; transition: background 0.2s;
    }
    .btn-add:hover { background: var(--primary-dark); }
    .tag {
      display: inline-block; font-size: 0.7rem; padding: 0.2rem 0.6rem;
      border-radius: 1rem; margin-bottom: 0.5rem;
    }
    .tag-new { background: #10b981; color: #fff; }
    .tag-sale { background: #f59e0b; color: #000; }

    /* ---- AWS Architecture Banner ---- */
    .arch-banner {
      background: linear-gradient(135deg, var(--surface), #162032);
      border: 1px solid var(--border); border-radius: 1rem;
      padding: 2rem; margin: 2rem 0; text-align: center;
    }
    .arch-banner h3 { color: var(--primary); margin-bottom: 1rem; font-size: 1.2rem; }
    .arch-flow {
      display: flex; flex-wrap: wrap; justify-content: center;
      align-items: center; gap: 0.5rem; font-size: 0.85rem;
    }
    .arch-node {
      background: var(--bg); border: 1px solid var(--border);
      padding: 0.4rem 0.8rem; border-radius: 0.5rem; color: var(--text);
    }
    .arch-arrow { color: var(--primary); font-weight: 700; }

    /* ---- Footer ---- */
    footer {
      text-align: center; padding: 2rem;
      border-top: 1px solid var(--border); color: var(--muted);
      font-size: 0.85rem; margin-top: 2rem;
    }
    footer strong { color: var(--primary); }
  </style>
</head>
<body>

  <header>
    <h1>🛍️ ShopAWS</h1>
    <p>A Production-Grade E-Commerce Application on AWS</p>
    <span class="badge">
      <span class="dot"></span>
      Live on AWS — ALB + Auto Scaling + RDS Multi-AZ
    </span>
  </header>

  <div class="infra-bar">
    <span>🖥️ Instance: <strong>$INSTANCE_ID</strong></span>
    <span>🌍 AZ: <strong>$AVAILABILITY_ZONE</strong></span>
    <span>⚙️ Type: <strong>$INSTANCE_TYPE</strong></span>
    <span>🗄️ DB: <strong>$DB_HOST</strong></span>
    <span>🌐 Env: <strong>$ENV_NAME</strong></span>
  </div>

  <nav>
    <a href="/">Home</a>
    <a href="#products">Products</a>
    <a href="#architecture">Architecture</a>
    <a href="/health">Health</a>
    <a class="cart-btn" href="#">🛒 Cart (0)</a>
  </nav>

  <div class="container">

    <h2 id="products">✨ Featured Products</h2>
    <div class="grid">

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#1e3a5f,#0ea5e9)">💻</div>
        <div class="card-body">
          <span class="tag tag-new">NEW</span>
          <h3>AWS DevCloud Laptop</h3>
          <div class="category">Computers</div>
          <div class="price">\$1,299.99 <span class="original">\$1,599.99</span></div>
          <p>High-performance development laptop pre-configured for AWS tooling.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#064e3b,#10b981)">📱</div>
        <div class="card-body">
          <span class="tag tag-sale">SALE</span>
          <h3>CloudPhone Pro Max</h3>
          <div class="category">Mobile</div>
          <div class="price">\$799.99 <span class="original">\$999.99</span></div>
          <p>Smartphone with seamless AWS IoT integration and cloud-native backup.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#4c1d95,#8b5cf6)">🎧</div>
        <div class="card-body">
          <h3>Echo Headset X Pro</h3>
          <div class="category">Audio</div>
          <div class="price">\$249.99</div>
          <p>Noise-cancelling headset with Alexa built-in and 40hr battery life.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#7c2d12,#f97316)">⌚</div>
        <div class="card-body">
          <span class="tag tag-new">NEW</span>
          <h3>SmartWatch Ultra</h3>
          <div class="category">Wearables</div>
          <div class="price">\$399.99</div>
          <p>IoT-enabled smartwatch connecting to AWS IoT Core for health analytics.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#0f4c75,#1b262c)">🖨️</div>
        <div class="card-body">
          <h3>CloudPrint Pro</h3>
          <div class="category">Office</div>
          <div class="price">\$179.99</div>
          <p>Wireless printer with direct S3 integration for cloud document printing.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

      <div class="card">
        <div class="card-img" style="background:linear-gradient(135deg,#1a1a2e,#e94560)">🎮</div>
        <div class="card-body">
          <span class="tag tag-sale">SALE</span>
          <h3>CloudPlay Console</h3>
          <div class="category">Gaming</div>
          <div class="price">\$449.99 <span class="original">\$549.99</span></div>
          <p>Next-gen gaming console with AWS GameLift integration for multiplayer.</p>
          <button class="btn-add" onclick="this.textContent='✅ Added!'">Add to Cart</button>
        </div>
      </div>

    </div>

    <!-- Architecture Banner -->
    <div class="arch-banner" id="architecture">
      <h3>🏗️ This App Runs on a Production AWS Architecture</h3>
      <div class="arch-flow">
        <div class="arch-node">👤 User</div><span class="arch-arrow">→</span>
        <div class="arch-node">🌐 Route 53</div><span class="arch-arrow">→</span>
        <div class="arch-node">☁️ CloudFront</div><span class="arch-arrow">→</span>
        <div class="arch-node">🛡️ WAF</div><span class="arch-arrow">→</span>
        <div class="arch-node">⚖️ ALB</div><span class="arch-arrow">→</span>
        <div class="arch-node">🖥️ EC2 ASG</div><span class="arch-arrow">→</span>
        <div class="arch-node">🗄️ RDS Multi-AZ</div>
      </div>
      <p style="margin-top:1rem;color:#94a3b8;font-size:0.85rem;">
        Deployed across 2 Availability Zones | Auto Scaling: 2–6 instances | CloudFront CDN
      </p>
    </div>

  </div>

  <footer>
    <p>© 2024 <strong>ShopAWS</strong> | AWS SAA Graduation Project | Author: Aziz Benchikh</p>
    <p style="margin-top:0.4rem">Architecture: Route 53 → CloudFront + WAF → ALB → EC2 Auto Scaling → RDS MySQL Multi-AZ</p>
  </footer>

</body>
</html>
HTMLEOF

# ---- 7. Create health check endpoint ----
echo "healthy" > /usr/share/nginx/html/health
echo "ok" > /usr/share/nginx/html/ping

# ---- 8. Configure Nginx ----
cat > /etc/nginx/conf.d/ecommerce.conf << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # Health check endpoint (no logging to reduce noise)
    location = /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    location = /ping {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }

    # Static assets with cache headers
    location /static/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Main app
    location / {
        try_files $uri $uri/ /index.html =404;
    }

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
NGINXEOF

# Remove default Nginx config
rm -f /etc/nginx/conf.d/default.conf

# ---- 9. Start Nginx ----
nginx -t  # Validate config
systemctl enable --now nginx
echo "=== Nginx started successfully ==="

# ---- 10. Configure CloudWatch Agent ----
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/var/log/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "namespace": "EcommerceApp/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 300
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/ecommerce/nginx/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/ecommerce/nginx/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "=== Bootstrap complete! Instance: $INSTANCE_ID | AZ: $AVAILABILITY_ZONE ==="
