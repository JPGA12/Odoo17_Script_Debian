#!/bin/bash

# Script de instalación de Odoo 17 en Debian Servidores GT
# Este script debe ejecutarse con privilegios de root (sudo)

# Colores para mejor visualización
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Iniciando instalación de Odoo 17 ===${NC}"

# Función para verificar si el último comando se ejecutó correctamente
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error en el paso anterior. Revise los mensajes de error y corrija antes de continuar.${NC}"
        exit 1
    fi
}

# 1. Actualizar el sistema
echo -e "${GREEN}[1/10] Actualizando el sistema...${NC}"
apt update
check_status
apt upgrade -y
check_status

# 2. Instalar dependencias necesarias
echo -e "${GREEN}[2/10] Instalando dependencias...${NC}"
# Primero instalamos curl
apt install -y curl

# Primero eliminamos versiones existentes de nodejs y npm
apt remove -y nodejs npm
apt autoremove -y

# Instalamos Node.js desde nodesource
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Instalamos PostgreSQL y sus dependencias de desarrollo
apt install -y postgresql postgresql-contrib postgresql-server-dev-15

# Instalamos el resto de dependencias
apt install -y build-essential python3-pil \
    python3-lxml python3-dev python3-pip python3-setuptools \
    git gdebi libldap2-dev libsasl2-dev libxml2-dev python3-wheel python3-venv \
    libxslt1-dev libjpeg-dev
check_status

# Instalamos less usando npm
npm install -g less
check_status

# 3. Verificar instalación de PostgreSQL y asegurar que esté funcionando
echo -e "${GREEN}[3/10] Verificando PostgreSQL...${NC}"
psql --version
check_status
systemctl status postgresql --no-pager
pg_ctlcluster 15 main start || true  # Use || true to continue if already running

# 4. Crear usuario para Odoo
echo -e "${GREEN}[4/10] Creando usuario para Odoo...${NC}"
if id "odoo17" >/dev/null 2>&1; then
    echo -e "${YELLOW}El usuario odoo17 ya existe, continuando...${NC}"
else
    useradd -m -d /opt/odoo17 -U -r -s /bin/bash odoo17
    check_status
fi

# Asegurarnos que el usuario existe en PostgreSQL
if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='odoo17'\"" | grep -q 1; then
    su - postgres -c "psql -c \"CREATE USER odoo17 WITH LOGIN SUPERUSER PASSWORD 'odoo17';\""
    check_status
else
    echo -e "${YELLOW}El usuario odoo17 ya existe en PostgreSQL, actualizando contraseña...${NC}"
    su - postgres -c "psql -c \"ALTER USER odoo17 WITH PASSWORD 'odoo17';\""
    check_status
fi

# 5. Crear directorios necesarios y establecer permisos
echo -e "${GREEN}[5/10] Creando directorios necesarios...${NC}"
mkdir -p /opt/odoo17
chown -R odoo17:odoo17 /opt/odoo17
chmod -R 755 /opt/odoo17

# 6. Instalar wkhtmltopdf (para reportes PDF)
echo -e "${GREEN}[6/10] Instalando wkhtmltopdf...${NC}"

# First install required dependencies
apt install -y fontconfig libfreetype6 libjpeg62-turbo libpng16-16 libx11-6 libxcb1 \
    libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g

# Download and install wkhtmltopdf for Debian
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb
check_status
apt install -y ./wkhtmltox_0.12.6.1-3.bookworm_amd64.deb
check_status
rm wkhtmltox_0.12.6.1-3.bookworm_amd64.deb

# 7. Clonar repositorio de Odoo e instalar dependencias
echo -e "${GREEN}[7/10] Clonando Odoo 17 desde GitHub...${NC}"
if [ -d "/opt/odoo17/odoo" ]; then
    echo -e "${YELLOW}El directorio /opt/odoo17/odoo ya existe. ¿Desea eliminarlo y volver a clonar? (s/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([sS][iI]|[sS])$ ]]; then
        rm -rf /opt/odoo17/odoo
        su - odoo17 -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo17/odoo"
        check_status
    else
        echo -e "${YELLOW}Continuando con el directorio existente...${NC}"
    fi
else
    su - odoo17 -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo17/odoo"
    check_status
fi

# Verificar y crear los directorios correctos
echo -e "${GREEN}Creando directorios si no existen...${NC}"

# Eliminar directorios existentes si hay problemas
rm -rf /odoo17/odoo/extra-addons
rm -rf /odoo17/odoo/enterprise

# Crear directorios limpios
mkdir -p /odoo17/odoo/extra-addons
mkdir -p /odoo17/odoo/enterprise

# Clonar repositorios
echo -e "${GREEN}Clonando repositorio FECOL...${NC}"
git clone https://github.com/alejoxdc/odoo17fecol.git /opt/odoo17/odoo/extra-addons
check_status

# Eliminar módulos que contengan 'acs'
echo -e "${GREEN}Eliminando módulos ACS...${NC}"
find /opt/odoo17/odoo/extra-addons -type d -name "*acs*" -exec rm -rf {} +
check_status

echo -e "${GREEN}Clonando repositorio Enterprise...${NC}"
git clone https://github.com/alejoxdc/odoo17fe.git /opt/odoo17/odoo/enterprise
check_status

# Establecer permisos correctos
echo -e "${GREEN}Estableciendo permisos correctos...${NC}"
chown -R odoo17:odoo17 /opt/odoo17
chmod -R 755 /opt/odoo17

# Configurar git para permitir el directorio
git config --global --add safe.directory /opt/odoo17/odoo/extra-addons
git config --global --add safe.directory /opt/odoo17/odoo/enterprise

# Configurar entorno virtual Python
echo -e "${GREEN}[7.1/10] Configurando entorno virtual Python...${NC}"
su - odoo17 -c "python3 -m venv /opt/odoo17/odoo/odoo-venv"
su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install --upgrade pip wheel setuptools"
check_status

# Instalar dependencias específicas de Greenlet y Gevent
su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install greenlet==2.0.2"
check_status
su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install gevent==22.10.2"
check_status

# Crear archivo temporal de requisitos sin gevent y greenlet
su - odoo17 -c "cat /opt/odoo17/odoo/requirements.txt | grep -v '^gevent' | grep -v '^greenlet' > /opt/odoo17/odoo/requirements_temp.txt"

# Instalar el resto de dependencias
su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install -r /opt/odoo17/odoo/requirements_temp.txt"
check_status

# Actualizar archivo de configuración
cat > /etc/odoo17.conf << EOF
[options]
admin_passwd = admin_password
db_host = localhost
db_port = 5432
db_user = odoo17
db_password = odoo17
addons_path = /opt/odoo17/odoo/addons,/opt/odoo17/odoo/extra-addons,/opt/odoo17/odoo/enterprise
xmlrpc_port = 8069
longpolling_port = 8072
workers = 2
proxy_mode = True
EOF

# Asegurar permisos del archivo de configuración
chown odoo17:odoo17 /etc/odoo17.conf
chmod 640 /etc/odoo17.conf

# Crear archivo de servicio para systemd
echo -e "${GREEN}Creando archivo de servicio para systemd...${NC}"
cat > /etc/systemd/system/odoo17.service << EOF
[Unit]
Description=Odoo17
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo17
PermissionsStartOnly=true
User=odoo17
Group=odoo17
ExecStart=/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf
StandardOutput=journal+console
Environment=PATH=/opt/odoo17/odoo/odoo-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Establecer permisos correctos para el archivo de servicio
chmod 644 /etc/systemd/system/odoo17.service

# Reiniciar servicios y habilitar Odoo para que inicie al arrancar
echo -e "${GREEN}Reiniciando servicios...${NC}"
systemctl daemon-reload
systemctl enable odoo17
systemctl restart odoo17

# Verificar estado sin sudo
systemctl status odoo17 --no-pager

# Monitorizar logs
journalctl -u odoo17 -f

echo -e "${GREEN}=== Instalación completada ===${NC}"
echo -e "Para ver los logs: ${YELLOW}journalctl -u odoo17${NC}"
echo -e "Acceda a Odoo desde su navegador: ${YELLOW}http://localhost:8069${NC}"
echo -e "IMPORTANTE: Recuerde cambiar 'admin_password' en /etc/odoo17.conf por una contraseña segura"
root@gt-s-odoo-02:/opt#