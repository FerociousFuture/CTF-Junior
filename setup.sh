#!/usr/bin/env bash
# --------------------------------------------------------------------
# Laboratorio de Puzle Lógico (OSINT)
# --------------------------------------------------------------------
# Instala httpd y telnet-server.
# Crea un usuario 'jperez' con una contraseña ('Chispas').
# Despliega un sitio web con pistas.
# INCLUYE SANEAMIENTO COMPLETO DE APACHE.
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/puzzle_lab_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Colores y Logging ---
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# --- Verificación de Root ---
if [ "$EUID" -ne 0 ]; then
  error "Este script debe ejecutarse como root o con sudo."
fi

info "Iniciando configuración del Laboratorio-Puzle Lógico..."
sleep 1

# --------------------------------------------------------
# 1. Instalación de Servicios
# --------------------------------------------------------
info "Instalando httpd (Apache), telnet-server, firewalld..."
dnf install -y httpd telnet-server firewalld net-tools >/dev/null || \
  error "Error al instalar los paquetes requeridos."
ok "Paquetes instalados."

# --------------------------------------------------------
# 2. Saneamiento de Apache (BLOQUE MEJORADO)
# --------------------------------------------------------
info "Limpiando configuraciones previas de Apache..."

# Deshabilita la página de bienvenida de Fedora (evita conflictos)
if [ -f /etc/httpd/conf.d/welcome.conf ]; then
  mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.bak
  ok "Página de bienvenida de Fedora deshabilitada."
fi

# Limpia drop-ins de systemd conflictivos (ej. php-fpm)
if [ -f /etc/systemd/system/httpd.service.d/php-fpm.conf ]; then
  rm -f /etc/systemd/system/httpd.service.d/php-fpm.conf
  ok "Archivo drop-in php-fpm.conf eliminado."
fi

# Define el puerto de escucha (Limpia configs anteriores)
sed -i '/^Listen /d' /etc/httpd/conf/httpd.conf
echo "Listen 80" >> /etc/httpd/conf/httpd.conf
ok "Puerto de Apache (Listen 80) re-configurado."


# --------------------------------------------------------
# 3. Creación de Usuario y Contraseña Vulnerable
# --------------------------------------------------------
info "Configurando el objetivo de Telnet..."
if ! id "jperez" &>/dev/null; then
    useradd jperez
    info "Usuario 'jperez' creado."
else
    info "Usuario 'jperez' ya existe."
fi

# Asignamos la contraseña 'Chispas' (La pista)
echo "Chispas" | passwd --stdin jperez >/dev/null
ok "Contraseña asignada al usuario 'jperez'."

# --------------------------------------------------------
# 4. Habilitación de Servicios y Firewall
# --------------------------------------------------------
info "Habilitando servicios y configurando firewall..."
systemctl enable --now telnet.socket || error "No se pudo iniciar Telnet."
systemctl enable --now httpd || error "No se pudo iniciar Apache."
systemctl enable --now firewalld || warn "No se pudo iniciar firewalld."

if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-service=http >/dev/null
  firewall-cmd --permanent --add-service=telnet >/dev/null
  firewall-cmd --reload
  ok "Firewall configurado (Puertos 80 y 23 abiertos)."
fi

# --------------------------------------------------------
# 5. Despliegue del Acertijo Web
# --------------------------------------------------------
info "Desplegando el sitio web..."
HTML_DIR="/var/www/html"
rm -rf "$HTML_DIR"/*
ok "Directorio web limpiado."

# --- Estilo CSS (compartido) ---
# ¡ARREGLADO! Se cambió el método 'read' por una asignación de variable estándar.
CSS_STYLE=$(cat <<'EOF'
<style>
    body { font-family: 'Verdana', sans-serif; margin: 0; padding: 0; background-color: #fdfdfd; }
    header { background-color: #333; color: white; padding: 20px; text-align: center; }
    .container { max-width: 800px; margin: 20px auto; padding: 20px; background-color: #fff; border: 1px solid #ddd; }
    .post { border-bottom: 1px solid #eee; padding-bottom: 20px; margin-bottom: 20px; }
    .post h2 { color: #0056b3; }
    .post-meta { font-size: 0.9em; color: #888; }
    nav { background: #444; padding: 10px; text-align: center; }
    nav a { color: white; padding: 10px 15px; text-decoration: none; font-weight: bold; }
    nav a:hover { background: #555; }
    .footer { text-align: center; font-size: 0.8em; color: #999; margin-top: 20px; }
</style>
EOF
)
ok "Variable CSS cargada en memoria."

# --- Página 1: El Blog (index.html) ---
cat <<HTML > "$HTML_DIR/index.html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Página Personal de Juan</title>
    $CSS_STYLE
</head>
<body>
    <header><h1>El Rincón de Juan Pérez</h1></header>
    <nav>
        <a href="index.html">Inicio</a>
        <a href="articulo.html">Artículos de Seguridad</a>
    </nav>
    
    <div class="container">
        <div class="post">
            <h2>Día en el parque</h2>
            <p class="post-meta">Publicado el 29 de Octubre, 2025</p>
            <p>Día increíble en el parque hoy. Llevé a mi perro y no paró de correr.</p>
            <p>Lo único malo fue que casi se come un frisbee que no era suyo... ¡este <strong>Chispas</strong> es terrible! Pero bueno, es imposible enfadarse con él.</p>
        </div>
        <div class="post">
            <h2>Nuevo servidor de pruebas</h2>
            <p class="post-meta">Publicado el 25 de Octubre, 2025</p>
            <p>¡Qué bien! Mi nuevo servidor de pruebas en la red interna ya está funcionando. Ahora puedo conectarme a <strong>Telnet</strong> desde cualquier parte de la oficina. Mucho más fácil que andar moviendo archivos.</p>
        </div>
    </div>
    <footer class="footer"><p>Página personal de Juan Pérez (jperez)</p></footer>
</body>
</html>
HTML
ok "index.html (Pista 1 y 2: Mascota y Servicio) creado."

# --- Página 2: La Pista (articulo.html) ---
cat <<HTML > "$HTML_DIR/articulo.html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Artículos de Seguridad</title>
    $CSS_STYLE
</head>
<body>
    <header><h1>El Rincón de Juan Pérez</h1></header>
    <nav>
        <a href="index.html">Inicio</a>
        <a href="articulo.html">Artículos de Seguridad</a>
    </nav>
    <div class="container">
        <div class="post">
            <h2>El Peligro de Compartir en Exceso (OSINT)</h2>
            <p class="post-meta">Artículo de "Seguridad-Hoy.com" (re-publicado)</p>
            <p>En la era digital, compartimos voluntariamente una cantidad ingente de información personal. Los atacantes ya no necesitan exploits complejos; solo necesitan leer.</p>
            <p>Este método, conocido como Inteligencia de Fuentes Abiertas (OSINT), es devastador. Un estudio reciente demostró que el <strong>nombre de una mascota</strong> es la segunda contraseña o "pregunta secreta" más común después de "123456".</p>
            <p>Los administradores de sistemas deben educar a su personal sobre los riesgos de mezclar información personal y credenciales de trabajo.</p>
        </div>
    </div>
    <footer class="footer"><p>Página personal de Juan Pérez (jperez)</p></footer>
</body>
</html>
HTML
ok "articulo.html (Pista 3: La vulnerabilidad) creado."

# --------------------------------------------------------
# 6. Aplicar Permisos
# --------------------------------------------------------
info "Aplicando permisos y contexto SELinux..."
chown -R apache:apache "$HTML_DIR"
restorecon -Rv "$HTML_DIR" >/dev/null 2>&1 || true
ok "Permisos aplicados."

# --------------------------------------------------------
# 7. Reinicio Final de Servicios
# --------------------------------------------------------
info "Reiniciando servicios para aplicar todos los cambios..."
systemctl restart httpd
systemctl restart telnet.socket

sleep 1
ok "✅ Configuración completa del Laboratorio-Puzle Lógico."
echo -e "${GREEN}Servicios expuestos:${NC}"
echo -e "  - ${CYAN}HTTP (Apache)${NC} en puerto ${YELLOW}80${NC}"
echo -e "  - ${CYAN}Telnet (Inseguro)${NC} en puerto ${YELLOW}23${NC}"
echo -e "¡El acertijo está listo!"