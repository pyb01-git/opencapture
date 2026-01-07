#!/bin/bash
set -ex

BRANCH="${GITHUB_HEAD_REF:-master}"
echo "Branch: $BRANCH"

# 1️⃣ Application retrieval
sudo rm -rf /var/www/html/opencapture/
sudo mkdir -p /var/www/html/opencapture/
sudo chmod -R 775 /var/www/html/opencapture/
sudo chown -R $(whoami):$(whoami) /var/www/html/opencapture/
sudo rm -rf /home/$(whoami)/python-venv/opencapture/

sudo apt update -y
sudo apt install -y git crudini
git clone -b $BRANCH https://github.com/pyb01-git/opencapture.git /var/www/html/opencapture/

# 2️⃣ Frontend
sudo apt install -y nodejs npm
cd /var/www/html/opencapture/src/frontend/
npm run reload-packages
npm run build-prod

# 3️⃣ Backend
cd /var/www/html/opencapture/install/
chmod u+x install.sh
sed -i 's/$(tput bold)/""/gI' install.sh
sed -i 's/$(tput sgr0)/""/gI' install.sh

sudo apt install -y postgresql
sudo su - postgres -c "psql -c 'DROP DATABASE IF EXISTS opencapture_test'"
sudo ./install.sh --custom_id test \
                   --user $(whoami) \
                   --path /var/www/html/opencapture/ \
                   --wsgi_process 1 \
                   --wsgi_threads 5 \
                   --supervisor_systemd systemd \
                   --database_hostname ${DB_HOST_NAME:-localhost} \
                   --database_port ${DB_PORT:-5432} \
                   --database_username ${DB_USER_NAME:-opencapture} \
                   --database_password ${DB_USER_PASSWORD:-opencapture} \
                   --docserver_path ${DOCSERVER_PATH:-/var/docservers/opencapture/}

# 4️⃣ Post-install checks
#sudo systemctl status OCSplitter-worker_test.service
#sudo systemctl status OCVerifier-worker_test.service
sudo systemctl start postgresql
#sudo systemctl status postgresql

# 5️⃣ Backend tests
source /home/$(whoami)/python-venv/opencapture/bin/activate
cd /var/www/html/opencapture/
python3 -m unittest discover src/backend/tests/
sudo su postgres -c "psql -c 'drop database opencapture_test'"

exit 0

# 6️⃣ Cleanup
sudo rm -rf /var/www/html/opencapture/
sudo rm -rf /var/docservers/
sudo rm -f /etc/apache2/sites-available/opencapture.conf
sudo rm -f /etc/systemd/system/OCVerifier-worker_test.conf
sudo rm -f /etc/systemd/system/OCSplitter-worker_test.conf
sudo systemctl daemon-reload
sudo systemctl restart apache2
