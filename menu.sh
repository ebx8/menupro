#!/bin/bash
# PANEL MULTITOOL VPS EBX8 - FULL
CYAN="\e[1;36m"; GREEN="\e[1;32m"; YELLOW="\e[1;33m"; RED="\e[1;31m"; RESET="\e[0m"

# ---------- FUNCIONES BÁSICAS DE COLORES Y PAUSA ----------
pausa() { read -p "Pulsa Enter para volver..."; }

# ---------- GESTIÓN DE USUARIOS SSH ----------
crear_usuario() { clear; echo -e "${CYAN}=== Crear Usuario SSH ===${RESET}"; read -p "Usuario: " user; read -s -p "Contraseña: " pass; echo; read -p "Días de validez: " dias; useradd -m -e $(date -d "$dias days" +"%Y-%m-%d") -s /bin/false "$user"; echo "$user:$pass" | chpasswd; echo -e "${GREEN}Usuario $user creado.${RESET}"; pausa; }
eliminar_usuario() { clear; echo -e "${CYAN}=== Eliminar Usuario SSH ===${RESET}"; read -p "Usuario a eliminar: " user; userdel -r "$user" && echo -e "${GREEN}Eliminado.${RESET}" || echo -e "${YELLOW}No existe.${RESET}"; pausa; }
listar_usuarios() { clear; echo -e "${CYAN}=== Usuarios SSH activos ===${RESET}"; for u in $(awk -F: '$7=="/bin/false"{print $1}' /etc/passwd); do expira=$(chage -l $u | grep "Account expires" | awk -F': ' '{print $2}'); echo "$u - Expira: $expira"; done; pausa; }

submenu_usuarios() {
    while true; do
        clear
        echo -e "${CYAN}==== GESTIÓN DE USUARIOS SSH ====${RESET}"
        echo "1. Crear usuario SSH"
        echo "2. Eliminar usuario SSH"
        echo "3. Listar usuarios SSH"
        echo "4. Volver"
        read -p "Opción [1-4]: " op
        case $op in
            1) crear_usuario ;;
            2) eliminar_usuario ;;
            3) listar_usuarios ;;
            4) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- CONTROL DE PUERTOS ----------
abrir_puerto() { clear; echo -e "${CYAN}=== ABRIR PUERTO TCP ===${RESET}"; read -p "Puerto TCP a abrir: " port; [[ -z "$port" ]] && { echo "No se ingresó puerto."; sleep 1; return; }; ufw allow $port/tcp || iptables -I INPUT -p tcp --dport $port -j ACCEPT; echo -e "${GREEN}Puerto $port abierto.${RESET}"; pausa; }
cerrar_puerto() { clear; echo -e "${CYAN}=== CERRAR PUERTO TCP ===${RESET}"; read -p "Puerto TCP a cerrar: " port; [[ -z "$port" ]] && { echo "No se ingresó puerto."; sleep 1; return; }; ufw delete allow $port/tcp || iptables -D INPUT -p tcp --dport $port -j ACCEPT; echo -e "${YELLOW}Puerto $port cerrado.${RESET}"; pausa; }

# ---------- BADVPN UDPGW ----------
instalar_badvpn() {
    clear
    echo -e "${CYAN}=== Instalar BADVPN UDPGW ===${RESET}"
    apt update -y
    apt install -y cmake build-essential git
    git clone https://github.com/ambrop72/badvpn.git 2>/dev/null || cd badvpn
    cd badvpn
    mkdir -p build && cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make
    cp udpgw/badvpn-udpgw /usr/bin/
    chmod +x /usr/bin/badvpn-udpgw
    cat >/etc/systemd/system/badvpn-udpgw.service <<EOF
[Unit]
Description=BADVPN UDPGW
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300
Restart=always
User=nobody
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable badvpn-udpgw
    systemctl restart badvpn-udpgw
    echo -e "${GREEN}BADVPN instalado y ejecutándose en el puerto 7300.${RESET}"
    pausa
}
detener_badvpn() { systemctl stop badvpn-udpgw && echo -e "${YELLOW}BADVPN detenido.${RESET}"; pausa; }
eliminar_badvpn() { systemctl stop badvpn-udpgw; systemctl disable badvpn-udpgw; rm -f /usr/bin/badvpn-udpgw; rm -f /etc/systemd/system/badvpn-udpgw.service; systemctl daemon-reload; echo -e "${RED}BADVPN eliminado.${RESET}"; pausa; }
estado_badvpn() { systemctl status badvpn-udpgw --no-pager | grep Active; ss -tulpn | grep 7300 || echo "Puerto 7300 cerrado."; pausa; }
submenu_badvpn() {
    while true; do
        clear
        echo -e "${CYAN}==== BADVPN UDPGW ====${RESET}"
        echo "1. Instalar BADVPN"
        echo "2. Detener BADVPN"
        echo "3. Eliminar BADVPN"
        echo "4. Estado BADVPN"
        echo "5. Volver"
        read -p "Opción [1-5]: " op
        case $op in
            1) instalar_badvpn ;;
            2) detener_badvpn ;;
            3) eliminar_badvpn ;;
            4) estado_badvpn ;;
            5) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- DROBEAR ----------
instalar_dropbear() {
    clear
    apt update -y
    apt install -y dropbear
    read -p "Puerto para Dropbear [predeterminado 443]: " dport
    [[ -z "$dport" ]] && dport=443
    sed -i "s/^NO_START.*/NO_START=0/" /etc/default/dropbear
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$dport/" /etc/default/dropbear
    systemctl enable dropbear
    systemctl restart dropbear
    echo -e "${GREEN}Dropbear instalado y ejecutándose en el puerto $dport.${RESET}"
    pausa
}
detener_dropbear() { systemctl stop dropbear && echo -e "${YELLOW}Dropbear detenido.${RESET}"; pausa; }
eliminar_dropbear() { systemctl stop dropbear; systemctl disable dropbear; apt remove -y dropbear; echo -e "${RED}Dropbear eliminado.${RESET}"; pausa; }
estado_dropbear() { systemctl status dropbear --no-pager | grep Active; ss -tulpn | grep dropbear || echo "Puerto no detectado."; pausa; }
submenu_dropbear() {
    while true; do
        clear
        echo -e "${CYAN}==== DROPBEAR SSH ====${RESET}"
        echo "1. Instalar Dropbear"
        echo "2. Detener Dropbear"
        echo "3. Eliminar Dropbear"
        echo "4. Estado Dropbear"
        echo "5. Volver"
        read -p "Opción [1-5]: " op
        case $op in
            1) instalar_dropbear ;;
            2) detener_dropbear ;;
            3) eliminar_dropbear ;;
            4) estado_dropbear ;;
            5) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- SQUID PROXY ----------
instalar_squid() {
    clear
    apt update -y
    apt install -y squid
    read -p "Puerto para Squid [predeterminado 3128]: " sport
    [[ -z "$sport" ]] && sport=3128
    sed -i "s/^http_port .*/http_port $sport/" /etc/squid/squid.conf
    systemctl enable squid
    systemctl restart squid
    echo -e "${GREEN}Squid instalado en el puerto $sport.${RESET}"
    pausa
}
detener_squid() { systemctl stop squid && echo -e "${YELLOW}Squid detenido.${RESET}"; pausa; }
eliminar_squid() { systemctl stop squid; systemctl disable squid; apt remove -y squid; echo -e "${RED}Squid eliminado.${RESET}"; pausa; }
estado_squid() { systemctl status squid --no-pager | grep Active; ss -tulpn | grep squid || echo "Puerto no detectado."; pausa; }
submenu_squid() {
    while true; do
        clear
        echo -e "${CYAN}==== SQUID PROXY ====${RESET}"
        echo "1. Instalar Squid"
        echo "2. Detener Squid"
        echo "3. Eliminar Squid"
        echo "4. Estado Squid"
        echo "5. Volver"
        read -p "Opción [1-5]: " op
        case $op in
            1) instalar_squid ;;
            2) detener_squid ;;
            3) eliminar_squid ;;
            4) estado_squid ;;
            5) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- STUNNEL ----------
instalar_stunnel() {
    clear
    apt update -y
    apt install -y stunnel4
    openssl req -new -x509 -days 365 -nodes -subj "/CN=localhost" -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem
    cat >/etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
client = no
[ssh]
accept = 444
connect = 127.0.0.1:22
EOF
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl enable stunnel4
    systemctl restart stunnel4
    echo -e "${GREEN}Stunnel instalado en el puerto 444.${RESET}"
    pausa
}
detener_stunnel() { systemctl stop stunnel4 && echo -e "${YELLOW}Stunnel detenido.${RESET}"; pausa; }
eliminar_stunnel() { systemctl stop stunnel4; systemctl disable stunnel4; apt remove -y stunnel4; echo -e "${RED}Stunnel eliminado.${RESET}"; pausa; }
estado_stunnel() { systemctl status stunnel4 --no-pager | grep Active; ss -tulpn | grep 444 || echo "Puerto 444 no detectado."; pausa; }
submenu_stunnel() {
    while true; do
        clear
        echo -e "${CYAN}==== STUNNEL (TLS/SSL) ====${RESET}"
        echo "1. Instalar Stunnel"
        echo "2. Detener Stunnel"
        echo "3. Eliminar Stunnel"
        echo "4. Estado Stunnel"
        echo "5. Volver"
        read -p "Opción [1-5]: " op
        case $op in
            1) instalar_stunnel ;;
            2) detener_stunnel ;;
            3) eliminar_stunnel ;;
            4) estado_stunnel ;;
            5) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- WEBSOCKET SSH (RELAX) ----------
crear_ws_relax() {
cat > ws-relax.js <<'EOF'
const net = require('net');
const http = require('http');
const server = http.createServer();
server.on('upgrade', (req, socket) => {
    const sshSocket = net.connect({ host: '127.0.0.1', port: 22 }, () => {
        socket.write('HTTP/1.1 101 Switching Protocols\r\n' +
                     'Upgrade: websocket\r\n' +
                     'Connection: Upgrade\r\n' +
                     '\r\n');
        sshSocket.pipe(socket);
        socket.pipe(sshSocket);
    });
    sshSocket.on('error', (err) => { socket.end(); });
    socket.on('error', (err) => { sshSocket.end(); });
});
server.listen(80, () => {
    console.log('WebSocket SSH proxy escuchando en el puerto 80 (modo relax)');
});
EOF
}
instalar_websocket() {
    clear
    echo -e "${CYAN}=== Instalar/activar WebSocket SSH (ws-relax.js) ===${RESET}"
    if ! command -v node >/dev/null 2>&1; then
        apt update -y && apt install -y nodejs npm
    fi
    if ! command -v pm2 >/dev/null 2>&1; then
        npm install -g pm2
    fi
    if [[ ! -f ws-relax.js ]]; then
        crear_ws_relax && echo -e "${GREEN}Archivo ws-relax.js creado.${RESET}"
    fi
    pm2 start ws-relax.js --name websocket-ssh
    pm2 save
    pm2 startup
    # --- AUTOMÁTICAMENTE ABRIR PUERTO 80 ---
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 80/tcp
    fi
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    echo -e "${GREEN}WebSocket activo en puerto 80.${RESET}"
    echo -e "${YELLOW}Puerto 80 (TCP) abierto automáticamente en el firewall. Si igual no conecta, revisa la nube/proveedor.${RESET}"
    pausa
}
detener_websocket() { pm2 stop websocket-ssh && echo -e "${YELLOW}WebSocket detenido.${RESET}"; pausa; }
eliminar_websocket() { pm2 delete websocket-ssh; rm -f ws-relax.js; echo -e "${RED}WebSocket eliminado.${RESET}"; pausa; }
estado_websocket() { pm2 list | grep websocket-ssh && ss -tulpn | grep 80 || echo "WebSocket no activo."; pausa; }
submenu_websocket() {
    while true; do
        clear
        echo -e "${CYAN}==== WEBSOCKET SSH (RELAX) ====${RESET}"
        echo "1. Instalar WebSocket"
        echo "2. Detener WebSocket"
        echo "3. Eliminar WebSocket"
        echo "4. Estado WebSocket"
        echo "5. Volver"
        read -p "Opción [1-5]: " op
        case $op in
            1) instalar_websocket ;;
            2) detener_websocket ;;
            3) eliminar_websocket ;;
            4) estado_websocket ;;
            5) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- ESTADO GENERAL DE SERVICIOS Y PUERTOS ----------
estado_servicios_inteligente() {
    clear
    echo -e "${CYAN}=== ESTADO DE SERVICIOS Y PUERTOS ===${RESET}"
    echo -e "SSH:        $(systemctl is-active ssh 2>/dev/null) (Puertos: $(ss -tulpn | grep sshd | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    echo -e "Dropbear:   $(systemctl is-active dropbear 2>/dev/null) (Puertos: $(ss -tulpn | grep dropbear | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    echo -e "BADVPN:     $(systemctl is-active badvpn-udpgw 2>/dev/null) (Puertos: $(ss -tulpn | grep badvpn-udpgw | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    echo -e "Squid:      $(systemctl is-active squid 2>/dev/null) (Puertos: $(ss -tulpn | grep squid | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    echo -e "Stunnel:    $(systemctl is-active stunnel4 2>/dev/null) (Puertos: $(ss -tulpn | grep 444 | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    echo -e "WebSocket:  $(pm2 list | grep -q websocket-ssh && echo online || echo offline) (Puertos: $(ss -tulpn | grep 80 | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | xargs))"
    pausa
}

# ---------- MENÚ PRINCIPAL ----------
while true; do
    clear
    echo -e "${CYAN}========== PANEL VPS EBX8 - MULTITOOL ==========${RESET}"
    echo "1. Estado de servicios y puertos"
    echo "2. Gestión de usuarios SSH"
    echo "3. BADVPN UDPGW"
    echo "4. Dropbear SSH"
    echo "5. Squid Proxy"
    echo "6. Stunnel (TLS/SSL)"
    echo "7. WebSocket SSH (Relax)"
    echo "8. Abrir/cerrar puertos TCP"
    echo "9. Salir"
    echo "-----------------------------------------"
    read -p "Selecciona una opción [1-9]: " mainopt
    case $mainopt in
        1) estado_servicios_inteligente ;;
        2) submenu_usuarios ;;
        3) submenu_badvpn ;;
        4) submenu_dropbear ;;
        5) submenu_squid ;;
        6) submenu_stunnel ;;
        7) submenu_websocket ;;
        8) abrir_puerto; cerrar_puerto ;;
        9) exit ;;
        *) echo "Opción inválida." ; sleep 1 ;;
    esac
done
