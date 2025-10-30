#!/bin/bash
# ==============================================================
#  Automated Setup Script for Flask + ZAP + Gunicorn + Nginx + MariaDB
#  Tested on Ubuntu (AWS EC2 Instance)
# ==============================================================

set -e  # Exit on error
set -o pipefail

#1-----------------------------------------------------------------------Generate values and setting variables---------
echo -e "${YELLOW}=== 1. Generate values and setting variables===${RESET}"

API_KEY=$(openssl rand -hex 16)

# --- CONFIGURABLE VARIABLES ---


ENV_DIR="/etc/myflaskapp"
SSL_DIR="/etc/nginx/ssl"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "EC2 Public IP: $PUBLIC_IP"

# --- COLORS ---
GREEN='\033[0;32m'
NC='\033[0m' # No Color
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo "The public IP address of this instance is: $PUBLIC_IP"
echo "The ZAP API KEY is: $API_KEY"
echo -e "${GREEN}Completed creating and declaring variables${RESET}"







#2----------------------------------------------------------------------------------Creating project user
echo -e "${YELLOW}=== 1. Creating New Project User ===${RESET}"

# --- Prompt for username ---
read -p "Enter new username: " PROJECT_USER

# Validate username
if id "$PROJECT_USER" &>/dev/null; then
    echo -e "${RED}User '$PROJECT_USER' already exists.${RESET}"
    exit 1
fi

# --- Prompt for password ---
read -s -p "Enter password for $PROJECT_USER: " PASSWORD
echo
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Passwords do not match!${RESET}"
    exit 1
fi

# --- Create user and home directory ---
echo -e "${YELLOW}Creating user '$PROJECT_USER'...${RESET}"

sudo useradd -m -s /bin/bash "$PROJECT_USER"

# --- Set password ---
echo "${PROJECT_USER}:${PASSWORD}" | sudo chpasswd

#3--------------------------------------------------------------------------------------------------Creating a project directory

echo -e "${YELLOW}=== 3. Creating a project Directory===${RESET}"


# --- Create project directory ---
PROJECT_DIR="/home/${PROJECT_USER}/zapproject"
echo -e "${YELLOW}Creating project directory at ${PROJECT_DIR}...${RESET}"
sudo mkdir -p "$PROJECT_DIR"



echo 'Adding user  {PROJECT_USER} to suddoers.........'

SUDOERS_D_FILE="/etc/sudoers.d/${PROJECT_USER}"

# Create a new sudoers file for the user
sudo touch "${SUDOERS_D_FILE}"
sudo chmod 0440 "${SUDOERS_D_FILE}" # Set appropriate permissions

# Add the user's sudo rule to the new file
echo "${PROJECT_USER} ALL=(ALL:ALL) ALL" | sudo tee "${SUDOERS_D_FILE}"



# --- Summary ---
echo -e "\n${GREEN}User and project directory setup complete!${RESET}"    
echo "==========================================="
echo "Username:     $PROJECT_USER"
echo "Project Dir:  $PROJECT_DIR"
echo "==========================================="

#4----------------------------------------------------------------------------------------------------Updating System and Installing Dependencies
echo -e "${YELLOW}=== 4.  Updating System and Installing Dependencies ===${RESET}"

sudo apt update -y
sudo apt install curl wget ca-certificates
echo "ZAP installation"

echo "📥 Fetching latest OWASP ZAP release URL..."
LATEST_URL=$(curl -s https://api.github.com/repos/zaproxy/zaproxy/releases/latest \
  | grep "browser_download_url.*Linux.tar.gz" \
  | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
  echo "❌ Failed to retrieve ZAP download URL."
  exit 1
fi



if [ -d "/opt/ZAP_*" ]; then
  echo "ZAP already installed. Skipping..."
else
  echo "➡  Downloading ZAP from $LATEST_URL ..."
  wget -q "$LATEST_URL" -O /tmp/ZAP_Linux.tar.gz || {
  echo "❌ Failed to download ZAP. Check network or URL."; exit 1;
  }

  echo "📦 Extracting ZAP..."
  sudo tar -xzf "/tmp/ZAP_Linux.tar.gz" -C "/opt"
  sudo chmod +x /opt/ZAP_*/zap.sh
  sudo ln -sf /opt/ZAP_*/zap.sh /usr/local/bin/zap
  # download & extract here
fi
echo "➡  Downloading ZAP from $LATEST_URL ..."
wget -q "$LATEST_URL" -O /tmp/ZAP_Linux.tar.gz || {
  echo "❌ Failed to download ZAP. Check network or URL."; exit 1;
}

echo "📦 Extracting ZAP..."
sudo tar -xzf "/tmp/ZAP_Linux.tar.gz" -C "/opt"
sudo chmod +x /opt/ZAP_*/zap.sh
sudo ln -sf /opt/ZAP_*/zap.sh /usr/local/bin/zap
echo "✅ ZAP installation complete."

sudo apt install -y python3 python3-venv python3-pip openjdk-17-jdk mariadb-server nginx openssl expect 

echo -e "\n${GREEN}System update and dependencies installation complete!${RESET}"
#6-------------------------------------------------------------------------------------------------------Configuring mariadb

echo -e "${YELLOW}===  Configuring MariaDB ........===${RESET}"

sudo systemctl start mariadb
sudo systemctl enable mariadb

read -s -p "Enter new root password for MariaDB: " DB_ROOT_PASS
echo
read -s -p "Confirm root password for MariadDB: " DB_ROOT_PASS1
echo

if [ "$DB_ROOT_PASS" != "$DB_ROOT_PASS1" ]; then
    echo -e "${RED}Passwords do not match!${RESET}"
    exit 1
fi

read -s -p "Enter password for application DB user: " DB_PASS
echo
read -s -p "Confirm password for application DB user: " DB_PASS1
echo

if [ "$DB_PASS" != "$DB_PASS1" ]; then
    echo -e "${RED}Passwords do not match!${RESET}"
    exit 1
fi
echo
read -p "Enter DB user for Flask Application: " DB_USER
echo
read -p "Enter DB Name: " DB_NAME
echo

# --- Secure Installation ---
echo -e "${YELLOW}Securing MariaDB installation...${RESET}"

# Attempting a non-interactive secure installation with `expect` (requires `expect` package)
# This is a more reliable way to automate `mariadb-secure-installation`
if command -v expect &> /dev/null; then
    echo "Using expect for secure installation..."
    expect -c "
        set timeout 10
        spawn sudo mariadb-secure-installation
        expect \"Enter current password for root (enter for none):\"
        send \"\r\"
        expect \"Set root password? [Y/n]\"
        send \"Y\r\"
        expect \"New password:\"
        send \"$DB_ROOT_PASS\r\"
        expect \"Re-enter new password:\"
        send \"$DB_ROOT_PASS\r\"
        expect \"Remove anonymous users? [Y/n]\"
        send \"Y\r\"
        expect \"Disallow root login remotely? [Y/n]\"
        send \"Y\r\"
        expect \"Remove test database and access to it? [Y/n]\"
        send \"Y\r\"
        expect \"Reload privilege tables now? [Y/n]\"
        send \"Y\r\"
        expect eof
    "
else
    echo "Expect is not installed. Please run 'sudo apt install expect' or perform secure installation manually."
    echo "Running mariadb-secure-installation (may require manual input):"
    sudo mariadb-secure-installation
fi


# Create a new user and database, grant privileges
echo "Creating user '$DB_USER' and database '$DB_NAME'..."
sudo mariadb -u root -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY "$DB_PASS";
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mariadb -u "$DB_USER" -p"$DB_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
USE $DB_NAME;

CREATE TABLE IF NOT EXISTS zap_scan (
    id INT AUTO_INCREMENT PRIMARY KEY,
    target_url VARCHAR(255),
    risk VARCHAR(50),
    alert VARCHAR(255),
    description TEXT,
    solution TEXT,
    scanned_at DATETIME
);
EOF

echo "Database table zap-scan succesifully created !!! "

echo "MariaDB installation and configuration complete!"
echo "User '$DB_USER' created with access to database '$DB_NAME'."


# --- Test Connection ---
echo -e "${YELLOW}Testing connection with new user...${RESET}"
mariadb -u "${DB_USER}" -p"${DB_PASS}" -e "SHOW DATABASES;" > /dev/null 2>&1 && \
echo -e "${GREEN}Connection successful!${RESET}" || \
echo -e "${RED}Connection failed! Check credentials.${RESET}"

# --- Output connection info ---
echo -e "\n${GREEN}MariaDB Setup Complete!${RESET}"
echo "======================================"
echo "Database:  ${DB_NAME}"
echo "Username:  ${DB_USER}"
echo "Password:  ${DB_PASS}"
echo "Root Pass: ${DB_ROOT_PASS}"
echo "======================================"


#5-------------------------------------------------------------------------------------------------------Creating.env



echo -e "${YELLOW}=== 5. Creating .env file.........===${RESET}"

sudo mkdir -p "$ENV_DIR"
cat > "$ENV_DIR/.env" <<EOF
PROJECT_USER=$PROJECT_USER
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_HOST=127.0.0.1
API_KEY=$API_KEY
ZAP_HOST=127.0.0.1
ZAP_PORT=8080
REPORT_DIR=/home/chada/zapproject/reports
EOF

set -a
source /etc/myflaskapp/.env
set +a

echo -e "${GREEN}.env file succesifully  created at $ENV_DIR/.env !${RESET}"





#7------------------------------------------------------------------------------------------Generating Self Sigfned Certificate


echo -e "${YELLOW}=== 7. Generating Self-Signed SSL Certificate .........................===${NC}"
sudo mkdir -p "${SSL_DIR}"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/C=US/ST=None/L=None/O=None/OU=None/CN=${DOMAIN_NAME}" \
  -keyout "${SSL_DIR}/nginx-selfsigned.key" \
  -out "${SSL_DIR}/nginx-selfsigned.crt"


#8----------------------------------------------------------------------------Setting file ownership and permisions

echo -e "${YELLOW}=== 8. Setting Permissions ===${NC}"
REPORT_DIR=/home/chada/zapproject/reports
sudo mkdir -p "${REPORT_DIR}"


sudo chown -R "${PROJECT_USER}":www-data "${PROJECT_DIR}"
sudo chmod -R 775 "${PROJECT_DIR}"
sudo chmod 775 /home/${PROJECT_USER}


sudo chown 775 /home/chada/zapproject/reports

sudo chown -R "${PROJECT_USER}":www-data /usr/local/bin/
sudo chmod 775 /usr/local/bin/zap


sudo chown -R "${PROJECT_USER}":www-data /opt/ZAP_*/


sudo mkdir -p /var/www/.ZAP
sudo chown -R www-data:www-data /var/www/.ZAP
sudo chmod -R 775 /var/www/.ZAP


sudo chmod 640 "$ENV_DIR/.env"
sudo chown -R chada:www-data /etc/myflaskapp/


#9-------------------------------------------Creating requirements.txt

echo -e "${YELLOW}=== 9. Creating requirements.txt ===${NC}"

cat > $PROJECT_DIR/requirements.txt <<EOF
Flask
Flask-SQLAlchemy
gunicorn
PyMySQL
python-dotenv
python-owasp-zap-v2.4
requests
SQLAlchemy
EOF

#10-----------------------------------------------------------------------------------Creating Python Virtual environment and pip install requirements.txt
echo -e "${YELLOW}=== 10. Creating Python Virtual Environment ===${NC}"
sudo -u "${PROJECT_USER}" bash -c "
cd ${PROJECT_DIR}
python3 -m venv zapvenv
source zapvenv/bin/activate
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi
deactivate
"


#11------------------------------------------------------------------Creating tempates folder f
echo -e "${YELLOW}=== 11. Creating templates folder at $PROJECT_DIR ===${RESET}"

mkdir -p $PROJECT_DIR/templates
cat > $PROJECT_DIR/templates/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>ZAP Scanner</title></head>
<body>
    <h1>Enter URL to Scan</h1>
    <form method="POST">
        <input type="text" name="url" required placeholder="https://example.com">
        <button type="submit">Start Scan</button>
    </form>
</body>
</html>

EOF


cat > $PROJECT_DIR/templates/results.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Scan Done</title></head>
<body>
    <h1>Scan Complete</h1>
    <p>Report ready: <a href="{{ url_for('download', report_name=report_name) }}">Download</a></p>
    <p><a href="{{ url_for('index') }}">Scan Another</a></p>
</body>
</html>

EOF

#12.------------------------------------------------------creating wsgi.py file

echo -e "${YELLOW}=== 12. Creating wsgi.py (Gunicorn Entry point) at $PROJECT_DIR ===${RESET}"

cat > $PROJECT_DIR/wsgi.py<<EOF
# wsgi.py
from app import app

if __name__ == "__main__":
    app.run()

EOF

#13-----------------------------------------------------creating app.py

echo -e "${YELLOW}=== 13. Creating app.py at $PROJECT_DIR ===${RESET}"

cat > $PROJECT_DIR/app.py <<EOF
from flask import Flask, render_template, request, redirect, url_for, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
from zapv2 import ZAPv2
import sys
sys.path.append('/home/chada/zapproject/zapvenv/lib/python3.13/site-packages')
import os
from dotenv import load_dotenv
import time
from datetime import datetime
from urllib.parse import quote_plus
load_dotenv("/etc/myflaskapp/.env")



#Caling Environment Variables

# --- CONFIG ---
app = Flask(__name__)
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_NAME = os.getenv("DB_NAME")
DB_HOST = os.getenv("DB_HOST")
ZAP_PORT = os.getenv("ZAP_PORT")
ZAP_HOST = os.getenv("ZAP_HOST")
API_KEY = os.getenv("API_KEY")
app.config['API_KEY'] = os.getenv('API_KEY')
REPORT_DIR = os.getenv("REPORT_DIR", "/home/chada/zapproject/reports")
app.config['SQLALCHEMY_DATABASE_URI'] = f"mariadb+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
zap = ZAPv2(apikey=app.config['API_KEY'],
            proxies={'http': f"http://{os.getenv('ZAP_HOST')}:{os.getenv('ZAP_PORT')}",
                     'https': f"http://{os.getenv('ZAP_HOST')}:{os.getenv('ZAP_PORT')}"})

os.makedirs(REPORT_DIR, exist_ok=True)

#...................................................................
# --- DATABASE MODEL ---
class scanner_results(db.Model):
    __tablename__ = 'zap_scan'
    id = db.Column(db.Integer, primary_key=True)
    target_url = db.Column(db.String(255))
    risk= db.Column(db.String(50))
    alert = db.Column(db.String(255))
    description = db.Column(db.Text)
    solution = db.Column(db.Text)
    scanned_at = db.Column(db.DateTime(timezone=True))
    
# --- ROUTES ---
@app.route('/',methods=['GET', 'POST'])
def index():

    if request.method == 'POST':
        target_url = request.form['url']
        return redirect(url_for('scan', target_url=target_url))
    return render_template('index.html')

@app.route('/scan')
def scan():
    target_url = request.args.get('target_url')
    print(target_url)
    time.sleep(2)

    # Access the URL
    zap.urlopen(target_url)
    time.sleep(2)

    # Save report
    filename = f"{target_url.replace('http://', '').replace('https://', '').replace('/', '_')}_report.html"
    report_path = os.path.join(REPORT_DIR, filename)
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(zap.core.htmlreport())


    # Save to DB
    result = scanner_results(target_url=target_url)
    db.session.add(result)
    db.session.commit()
    return render_template('results.html', report_name=filename)

@app.route('/download/<report_name>')
def download(report_name):
    return send_from_directory(REPORT_DIR, report_name, as_attachment=True)

# --- MAIN ---
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)


EOF


#14---------------------------------------------------------------------------------Creating Systemd services for Gunicoprn and ZAPROXY
echo -e "${YELLOW}=== 14. Creating Systemd Services Placeholders ===${RESET}"


# ZAP Proxy service
sudo tee /etc/systemd/system/zaproxy.service > /dev/null <<EOL
[Unit]
Description=OWASP ZAP Proxy
After=network.target

[Service]
Type=simple
User=chada
Group=www-data
Environment="HOME=/etc/myflaskapp"
EnvironmentFile=/etc/myflaskapp/.env
ExecStart=/bin/bash -c '/usr/local/bin/zap -daemon -host ${ZAP_HOST} -port ${ZAP_PORT} -config api.key=${API_KEY}'
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Gunicorn service
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOL
[Unit]
Description=Gunicorn Flask App
After=network.target

[Service]                                                                      
User=chada
Group=www-data
WorkingDirectory=/home/chada/zapproject
EnvironmentFile=/etc/myflaskapp/.env
Environment="PATH=/home/chada/zapproject/zapvenv/bin"
Environment="HOME=/etc"
ExecStart=/home/chada/zapproject/zapvenv/bin/gunicorn --workers 3 --bind unix:/home/chada/zapproject/zapflask.sock wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

#15-------------------------------------------------------------------------------------Reloading and Enabling services
echo -e "${YELLOW}=== 15. Reloading and Enabling Services ===${RESET}"
sudo systemctl daemon-reload
sudo systemctl enable --now zaproxy.service
sudo systemctl enable --now gunicorn.service
#16------------------------------------------------------------------------------------Nginx Configuration place holder

echo -e "${YELLOW}=== 16. Nginx Configuration Placeholder........ ===${RESET}"

sudo mkdir -p $SSL_DIR
sudo tee /etc/nginx/sites-available/zapnginx > /dev/null <<EOL
server {
    listen 443 ssl;
    server_name ${PUBLIC_IP};

    ssl_certificate ${SSL_DIR}/nginx-selfsigned.crt;
    ssl_certificate_key ${SSL_DIR}/nginx-selfsigned.key;

    location / {
        proxy_pass http://unix:${PROJECT_DIR}/zapflask.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 80;
    server_name ${PUBLIC_IP};
    return 301 https://\$host\$request_uri;
}
EOL

sudo ln -sf /etc/nginx/sites-available/zapnginx /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
#------------------------------------------------------------------------------------------
echo -e "${GREEN}=== Setup Complete! ===${RESET}"

echo -e "${GREEN}Access your Flask app via: https://${PUBLIC_IP}/ ${RESET}"