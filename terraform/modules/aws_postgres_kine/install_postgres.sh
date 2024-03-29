#!/usr/bin/env bash

set -xe

# Install the repository
mkdir -p /etc/yum.repos.d/
cat >/etc/yum.repos.d/pg.repo <<EOF
[pg15]
name=PostgreSQL 15 for RHEL/CentOS 7 - `uname -m`
baseurl=https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-`uname -m`
enabled=1
gpgcheck=0
EOF

# Install PostgreSQL
yum install -y postgresql15 postgresql15-server

# use data disk if available (see mount_ephemeral.sh)
if [ -d /data ]; then
  mkdir -p /data/pgsql
  ln -sf /data/pgsql /var/lib/pgsql
endif

# Initialize the database and enable automatic start
ls /var/lib/pgsql/15/initdb.log || /usr/pgsql-15/bin/postgresql-15-setup initdb

# Set basic tuning parameters
cat >>/var/lib/pgsql/15/data/postgresql.conf <<EOF
# Tuning parameters from https://pgtune.leopard.in.ua/ based on instance type m6id.4xlarge
# DB Version: 15
# OS Type: linux
# DB Type: web
# Total Memory (RAM): 64 GB
# CPUs num: 16
# Connections num: 50
# Data Storage: ssd

max_connections = 50
shared_buffers = 16GB
effective_cache_size = 48GB
maintenance_work_mem = 2GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 83886kB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 16
max_parallel_workers_per_gather = 4
max_parallel_workers = 16
max_parallel_maintenance_workers = 4
EOF

# Start DB
systemctl enable postgresql-15
systemctl start postgresql-15

# Create kine user
su - postgres -c psql <<EOF
  CREATE USER kineuser WITH PASSWORD 'kinepassword';
  CREATE DATABASE kine LOCALE 'C' TEMPLATE 'template0';
  GRANT ALL ON DATABASE kine TO kineuser;
  ALTER DATABASE kine OWNER TO kineuser;
EOF

# Install kine
if [ -s /tmp/kine ]; then
  mv -f /tmp/kine /usr/bin/kine
else
  curl -L -o /usr/bin/kine https://github.com/k3s-io/kine/releases/download/${kine_version}/kine-`uname -m | sed 's/x86_64/amd64/'`
  chmod +x /usr/bin/kine
fi

cat >/etc/systemd/system/kine.service <<EOF
[Unit]
Description=kine

[Service]
ExecStart=/usr/bin/kine --endpoint postgres://kineuser:kinepassword@localhost:5432/kine?sslmode=disable
%{ if gogc != null ~}
Environment="GOGC=${gogc}"
%{ endif ~}

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

# Start kine
systemctl enable kine
systemctl start kine
