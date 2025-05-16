# Instalación de Odoo 17 en Debian

Este documento proporciona instrucciones detalladas para la instalación de Odoo 17 en servidores Debian. La instalación incluye el sistema base de Odoo, el repositorio Enterprise y módulos adicionales personalizados.

## Requisitos del Sistema

- Debian 12 (Bookworm) o superior
- Acceso root o privilegios sudo
- Mínimo 4GB de RAM (8GB recomendado)
- 20GB de espacio en disco (mínimo)
- Conexión a Internet

## Proceso de Instalación

La instalación se realiza mediante un script bash que automatiza todo el proceso. El script realiza las siguientes acciones:

1. Actualiza el sistema
2. Instala todas las dependencias necesarias
3. Configura PostgreSQL
4. Crea un usuario dedicado para Odoo
5. Instala wkhtmltopdf para generación de reportes PDF
6. Clona el repositorio oficial de Odoo 17
7. Clona repositorios adicionales (Enterprise y módulos personalizados)
8. Configura un entorno virtual Python
9. Instala las dependencias de Python
10. Configura el servicio systemd para Odoo

## Ejecución del Script

1. Guarde el script en un archivo (por ejemplo, `install_odoo17.sh`)
2. Otorgue permisos de ejecución:
   ```bash
   chmod +x install_odoo17.sh
   ```
3. Ejecute el script con privilegios root:
   ```bash
   sudo ./install_odoo17.sh
   ```

## Estructura de Directorios

Después de la instalación, los directorios principales son:

- `/opt/odoo17/odoo` - Código fuente de Odoo
- `/opt/odoo17/odoo/enterprise` - Módulos Enterprise
- `/opt/odoo17/odoo/extra-addons` - Módulos personalizados
- `/opt/odoo17/odoo/odoo-venv` - Entorno virtual Python

## Archivos de Configuración

- Configuración principal: `/etc/odoo17.conf`
- Servicio systemd: `/etc/systemd/system/odoo17.service`

## Gestión del Servicio

### Iniciar Odoo
```bash
sudo systemctl start odoo17
```

### Detener Odoo
```bash
sudo systemctl stop odoo17
```

### Reiniciar Odoo
```bash
sudo systemctl restart odoo17
```

### Verificar estado
```bash
sudo systemctl status odoo17
```

### Ver logs
```bash
sudo journalctl -u odoo17 -f
```

## Acceso a Odoo

Una vez instalado, puede acceder a Odoo desde su navegador:
- URL: `http://[dirección_IP]:8069`
- Base de datos: Debe crear una nueva al primer inicio
- Usuario: `admin`
- Contraseña: Se define al crear la base de datos

## Configuración de Seguridad

Por defecto, el script configura la contraseña maestra de Odoo como `admin_password`. Es altamente recomendable cambiarla:

1. Edite el archivo de configuración:
   ```bash
   sudo nano /etc/odoo17.conf
   ```
2. Modifique la línea `admin_passwd = admin_password` con una contraseña segura

## Configuración Adicional

### Puertos
- XML-RPC (interfaz web): 8069
- Longpolling (para notificaciones): 8072

### Modo Proxy
Por defecto, el script configura Odoo en modo proxy (`proxy_mode = True`). Esto es adecuado si planea utilizar un proxy inverso como Nginx.

### Número de Trabajadores
El script configura 2 trabajadores por defecto. Puede ajustar este número según los recursos de su servidor:
- Fórmula recomendada: `(Número de CPU * 2) + 1`
- Edite la línea `workers = 2` en el archivo de configuración

## Solución de Problemas

### Error de Permisos
Si encuentra errores de permisos:
```bash
sudo chown -R odoo17:odoo17 /opt/odoo17
sudo chmod -R 755 /opt/odoo17
```

### Error de PostgreSQL
Si PostgreSQL no se inicia:
```bash
sudo pg_ctlcluster 15 main start
```

### Error de Dependencias Python
Si hay problemas con las dependencias de Python:
```bash
sudo su - odoo17
source /opt/odoo17/odoo/odoo-venv/bin/activate
pip install -r /opt/odoo17/odoo/requirements.txt
```

### Error de Acceso Web
Si no puede acceder a Odoo desde el navegador:
1. Verifique que el servicio esté en ejecución
2. Compruebe si el firewall está bloqueando el puerto 8069
3. Verifique los logs para más detalles

## Actualizaciones

Para actualizar Odoo a la última versión de la rama 17.0:

```bash
sudo su - odoo17
cd /opt/odoo17/odoo
git pull
cd /opt/odoo17/odoo/enterprise
git pull
cd /opt/odoo17/odoo/extra-addons
git pull
source /opt/odoo17/odoo/odoo-venv/bin/activate
pip install -r requirements.txt
exit
sudo systemctl restart odoo17
```

## Notas Importantes

- Este script está optimizado para Debian 12 (Bookworm)
- La instalación incluye Node.js 18.x para la compilación de assets
- Se han instalado las versiones específicas de greenlet (2.0.2) y gevent (22.10.2) para evitar problemas de compatibilidad

## Respaldo y Restauración

### Respaldo de Base de Datos
```bash
sudo su - odoo17
cd /opt/odoo17
/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf -d [nombre_bd] --backup --stop-after-init
```

### Restauración de Base de Datos
```bash
sudo su - odoo17
cd /opt/odoo17
/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf -d [nombre_bd_nueva] --restore_file=[archivo_respaldo] --stop-after-init
```

## Soporte

Para problemas relacionados con esta instalación, consulte la documentación oficial de Odoo:
- [Documentación Odoo](https://www.odoo.com/documentation/17.0/)
- [Foro de la comunidad Odoo](https://www.odoo.com/forum/help-1)
