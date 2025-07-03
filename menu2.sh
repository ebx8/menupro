#!/bin/bash
# PANEL MULTITOOL VPS EBX8 - FULL
CYAN="\e[1;36m"; GREEN="\e[1;32m"; YELLOW="\e[1;33m"; RED="\e[1;31m"; RESET="\e[0m"

# ---------- FUNCIONES BÁSICAS DE COLORES Y PAUSA ----------
pausa() { read -p "Pulsa Enter para volver..."; }

# ---------- GESTIÓN DE USUARIOS SSH ----------
crear_usuario() {
    clear; echo -e "${CYAN}=== Crear Usuario SSH ===${RESET}"
    read -p "Usuario: " user
    read -s -p "Contraseña: " pass; echo
    read -p "Días de validez: " dias
    # crea usuario con shell /bin/bash
    useradd -m -e "$(date -d "$dias days" +"%Y-%m-%d")" -s /bin/bash "$user"
    echo "$user:$pass" | chpasswd
    echo -e "${GREEN}Usuario $user creado con shell /bin/bash.${RESET}"
    pausa
}
eliminar_usuario() {
    clear; echo -e "${CYAN}=== Eliminar Usuario SSH ===${RESET}"
    read -p "Usuario a eliminar: " user
    if userdel -r "$user"; then
        echo -e "${GREEN}Usuario $user eliminado.${RESET}"
    else
        echo -e "${YELLOW}El usuario $user no existe.${RESET}"
    fi
    pausa
}
listar_usuarios() {
    clear; echo -e "${CYAN}=== Usuarios SSH activos (/bin/bash) ===${RESET}"
    while IFS=: read -r u _ _ _ _ _ shell; do
        if [[ "$shell" == "/bin/bash" ]]; then
            expira=$(chage -l "$u" | awk -F': ' '/Account expires/ {print $2}')
            echo "$u – Expira: $expira"
        fi
    done < /etc/passwd
    pausa
}
submenu_usuarios() {
    while true; do
        clear
        echo -e "${CYAN}==== GESTIÓN DE USUARIOS SSH ====${RESET}"
        echo "1) Crear usuario SSH"
        echo "2) Eliminar usuario SSH"
        echo "3) Listar usuarios SSH"
        echo "4) Volver"
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

# ---------- CONTROL DE PUERTOS TCP GENÉRICO ----------
abrir_puerto() {
    clear; echo -e "${CYAN}=== ABRIR PUERTO TCP ===${RESET}"
    read -p "Puerto TCP a abrir: " port
    [[ -z "$port" ]] && { echo "No se ingresó puerto."; sleep 1; return; }
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow "$port"/tcp
    else
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    fi
    echo -e "${GREEN}Puerto $port abierto.${RESET}"
    pausa
}
cerrar_puerto() {
    clear; echo -e "${CYAN}=== CERRAR PUERTO TCP ===${RESET}"
    read -p "Puerto TCP a cerrar: " port
    [[ -z "$port" ]] && { echo "No se ingresó puerto."; sleep 1; return; }
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw delete allow "$port"/tcp
    else
        iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    fi
    echo -e "${YELLOW}Puerto $port cerrado.${RESET}"
    pausa
}

# ---------- BADVPN UDPGW (Puerto único) ----------
instalar_badvpn() {
    clear; echo -e "${CYAN}=== Instalar BADVPN UDPGW ===${RESET}"
    apt update -y
    apt install -y cmake build-essential git
    git clone https://github.com/ambrop72/badvpn.git badvpn-src 2>/dev/null || true
    cd badvpn-src
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
    # Abrir firewall UDP
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow 7300/udp
    else
        iptables -I INPUT -p udp --dport 7300 -j ACCEPT
    fi
    echo -e "${GREEN}BADVPN instalado en el puerto 7300 (UDP).${RESET}"
    pausa
}
detener_badvpn() {
    systemctl stop badvpn-udpgw && echo -e "${YELLOW}BADVPN detenido.${RESET}"
    pausa
}
eliminar_badvpn() {
    systemctl stop badvpn-udpgw
    systemctl disable badvpn-udpgw
    rm -f /usr/bin/badvpn-udpgw /etc/systemd/system/badvpn-udpgw.service
    systemctl daemon-reload
    echo -e "${RED}BADVPN eliminado.${RESET}"
    pausa
}
estado_badvpn() {
    clear; echo -e "${CYAN}=== Estado BADVPN UDPGW ===${RESET}"
    systemctl status badvpn-udpgw --no-pager | grep Active
    ss -u -ltnp | grep 7300 || echo "Puerto 7300 no en escucha."
    pausa
}
submenu_badvpn() {
    while true; do
        clear
        echo -e "${CYAN}==== BADVPN UDPGW ====${RESET}"
        echo "1) Instalar BADVPN"
        echo "2) Detener BADVPN"
        echo "3) Eliminar BADVPN"
        echo "4) Estado BADVPN"
        echo "5) Volver"
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

# ---------- DROPBEAR SSH (Multi-puerto + firewall automático) ----------
instalar_dropbear() {
    clear; echo -e "${CYAN}=== Instalar Dropbear ===${RESET}"
    apt update -y
    apt install -y dropbear
    read -p "Puerto para Dropbear [predeterminado 443]: " dport
    [[ -z "$dport" ]] && dport=443
    sed -i "s/^NO_START=.*/NO_START=0/" /etc/default/dropbear
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$dport/" /etc/default/dropbear
    systemctl enable dropbear
    systemctl restart dropbear

    # Mostrar estado firewall
    ufw status verbose -n --line-numbers 2>/dev/null || echo "UFW no activo o no instalado"
    iptables -L INPUT -n --line-numbers

    # Abrir puerto en firewall
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow "${dport}/tcp"
    else
        iptables -I INPUT 1 -p tcp --dport "$dport" -j ACCEPT
    fi

    echo -e "${GREEN}Dropbear instalado y escuchando en el puerto $dport.${RESET}"
    pausa
}
cambiar_puerto_dropbear() {
    clear; echo -e "${CYAN}=== Cambiar Puerto Dropbear ===${RESET}"
    oldport=$(grep '^DROPBEAR_PORT=' /etc/default/dropbear | cut -d'=' -f2)
    read -p "Nuevo puerto para Dropbear: " nport
    [[ -z "$nport" ]] && { echo "No se ingresó puerto."; sleep 1; return; }

    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$nport/" /etc/default/dropbear
    systemctl restart dropbear

    # Mostrar estado firewall
    ufw status verbose -n --line-numbers 2>/dev/null || echo "UFW no activo o no instalado"
    iptables -L INPUT -n --line-numbers

    # Ajustar reglas firewall
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw delete allow "${oldport}/tcp" 2>/dev/null || true
        ufw allow "${nport}/tcp"
    else
        iptables -D INPUT -p tcp --dport "$oldport" -j ACCEPT 2>/dev/null || true
        iptables -I INPUT 1 -p tcp --dport "$nport" -j ACCEPT
    fi

    echo -e "${GREEN}Puerto Dropbear cambiado de $oldport a $nport.${RESET}"
    pausa
}
detener_dropbear() {
    systemctl stop dropbear && echo -e "${YELLOW}Dropbear detenido.${RESET}"
    pausa
}
eliminar_dropbear() {
    systemctl stop dropbear
    systemctl disable dropbear
    apt remove -y dropbear
    echo -e "${RED}Dropbear eliminado.${RESET}"
    pausa
}
estado_dropbear() {
    clear; echo -e "${CYAN}=== Estado Dropbear ===${RESET}"
    systemctl status dropbear --no-pager | grep Active
    ss -tulpn | grep dropbear || echo "Dropbear no en escucha."
    pausa
}
submenu_dropbear() {
    while true; do
        clear
        echo -e "${CYAN}==== DROPBEAR SSH ====${RESET}"
        echo "1) Instalar Dropbear"
        echo "2) Detener Dropbear"
        echo "3) Eliminar Dropbear"
        echo "4) Estado Dropbear"
        echo "5) Cambiar puerto Dropbear"
        echo "6) Volver"
        read -p "Opción [1-6]: " op
        case $op in
            1) instalar_dropbear ;;
            2) detener_dropbear ;;
            3) eliminar_dropbear ;;
            4) estado_dropbear ;;
            5) cambiar_puerto_dropbear ;;
            6) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- SQUID PROXY (Multi-puerto) ----------
instalar_squid() {
    clear; echo -e "${CYAN}=== Instalar Squid ===${RESET}"
    apt update -y
    apt install -y squid
    read -p "Puerto para Squid [predeterminado 3128]: " sport
    [[ -z "$sport" ]] && sport=3128
    sed -i "s/^http_port .*/http_port $sport/" /etc/squid/squid.conf
    systemctl enable squid
    systemctl restart squid
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow "${sport}/tcp"
    else
        iptables -I INPUT -p tcp --dport "$sport" -j ACCEPT
    fi
    echo -e "${GREEN}Squid instalado y escuchando en el puerto $sport.${RESET}"
    pausa
}
cambiar_puerto_squid() {
    clear; echo -e "${CYAN}=== Cambiar Puerto Squid ===${RESET}"
    oldport=$(awk '/^http_port/ {print $2; exit}' /etc/squid/squid.conf)
    read -p "Nuevo puerto para Squid: " nport
    [[ -z "$nport" ]] && { echo "No se ingresó puerto."; sleep 1; return; }
    sed -i "s/^http_port .*/http_port $nport/" /etc/squid/squid.conf
    systemctl restart squid
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw delete allow "${oldport}/tcp" 2>/dev/null || true
        ufw allow "${nport}/tcp"
    else
        iptables -D INPUT -p tcp --dport "$oldport" -j ACCEPT 2>/dev/null || true
        iptables -I INPUT 1 -p tcp --dport "$nport" -j ACCEPT
    fi
    echo -e "${GREEN}Puerto Squid cambiado de $oldport a $nport.${RESET}"
    pausa
}
detener_squid() {
    systemctl stop squid && echo -e "${YELLOW}Squid detenido.${RESET}"
    pausa
}
eliminar_squid() {
    systemctl stop squid
    systemctl disable squid
    apt remove -y squid
    echo -e "${RED}Squid eliminado.${RESET}"
    pausa
}
estado_squid() {
    clear; echo -e "${CYAN}=== Estado Squid ===${RESET}"
    systemctl status squid --no-pager | grep Active
    ss -tulpn | grep squid || echo "Squid no en escucha."
    pausa
}
submenu_squid() {
    while true; do
        clear
        echo -e "${CYAN}==== SQUID PROXY ====${RESET}"
        echo "1) Instalar Squid"
        echo "2) Detener Squid"
        echo "3) Eliminar Squid"
        echo "4) Estado Squid"
        echo "5) Cambiar puerto Squid"
        echo "6) Volver"
        read -p "Opción [1-6]: " op
        case $op in
            1) instalar_squid ;;
            2) detener_squid ;;
            3) eliminar_squid ;;
            4) estado_squid ;;
            5) cambiar_puerto_squid ;;
            6) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- STUNNEL (Multi-puerto) ----------
instalar_stunnel() {
    clear; echo -e "${CYAN}=== Instalar Stunnel ===${RESET}"
    apt update -y
    apt install -y stunnel4 openssl
    read -p "Puerto para Stunnel [predeterminado 444]: " sport
    [[ -z "$sport" ]] && sport=444
    openssl req -new -x509 -days 365 -nodes \
        -subj "/CN=localhost" \
        -out /etc/stunnel/stunnel.pem \
        -keyout /etc/stunnel/stunnel.pem
    cat >/etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
client = no
[ssh]
accept = $sport
connect = 127.0.0.1:22
EOF
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl enable stunnel4
    systemctl restart stunnel4
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow "${sport}/tcp"
    else
        iptables -I INPUT -p tcp --dport "$sport" -j ACCEPT
    fi
    echo -e "${GREEN}Stunnel instalado y escuchando en el puerto $sport.${RESET}"
    pausa
}
cambiar_puerto_stunnel() {
    clear; echo -e "${CYAN}=== Cambiar Puerto Stunnel ===${RESET}"
    oldport=$(awk '/accept =/ {print $3; exit}' /etc/stunnel/stunnel.conf)
    read -p "Nuevo puerto para Stunnel: " nport
    [[ -z "$nport" ]] && { echo "No se ingresó puerto."; sleep 1; return; }
    sed -i "s/^accept = .*/accept = $nport/" /etc/stunnel/stunnel.conf
    systemctl restart stunnel4
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw delete allow "${oldport}/tcp" 2>/dev/null || true
        ufw allow "${nport}/tcp"
    else
        iptables -D INPUT -p tcp --dport "$oldport" -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport "$nport" -j ACCEPT
    fi
    echo -e "${GREEN}Puerto Stunnel cambiado de $oldport a $nport.${RESET}"
    pausa
}
detener_stunnel() {
    systemctl stop stunnel4 && echo -e "${YELLOW}Stunnel detenido.${RESET}"
    pausa
}
eliminar_stunnel() {
    systemctl stop stunnel4
    systemctl disable stunnel4
    apt remove -y stunnel4
    echo -e "${RED}Stunnel eliminado.${RESET}"
    pausa
}
estado_stunnel() {
    clear; echo -e "${CYAN}=== Estado Stunnel ===${RESET}"
    systemctl status stunnel4 --no-pager | grep Active
    ss -tulpn | grep stunnel4 || echo "Stunnel no en escucha."
    pausa
}
submenu_stunnel() {
    while true; do
        clear
        echo -e "${CYAN}==== STUNNEL (TLS/SSL) ====${RESET}"
        echo "1) Instalar Stunnel"
        echo "2) Detener Stunnel"
        echo "3) Eliminar Stunnel"
        echo "4) Estado Stunnel"
        echo "5) Cambiar puerto Stunnel"
        echo "6) Volver"
        read -p "Opción [1-6]: " op
        case $op in
            1) instalar_stunnel ;;
            2) detener_stunnel ;;
            3) eliminar_stunnel ;;
            4) estado_stunnel ;;
            5) cambiar_puerto_stunnel ;;
            6) break ;;
            *) echo "Opción inválida." ; sleep 1 ;;
        esac
    done
}

# ---------- WEBSOCKET SSH (RELAX) ----------
crear_ws_relax() {
    cat > ws-relax.js <<'EOF'
const net = require('net'), http = require('http');
const server = http.createServer();
server.on('upgrade', (req, socket) => {
    const ssh = net.connect({host:'127.0.0.1',port:22}, () => {
        socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n');
        ssh.pipe(socket); socket.pipe(ssh);
    });
    ssh.on('error', () => socket.end());
    socket.on('error', () => ssh.end());
});
server.listen(80, () => console.log('WebSocket SSH escuchando en el puerto 80'));
EOF
}
instalar_websocket() {
    clear; echo -e "${CYAN}=== Instalar WebSocket SSH ===${RESET}"
    apt update -y && apt install -y nodejs npm
    npm install -g pm2
    [[ ! -f ws-relax.js ]] && crear_ws_relax && echo -e "${GREEN}Archivo ws-relax.js creado.${RESET}"
    pm2 start ws-relax.js --name websocket-ssh
    pm2 save; pm2 startup
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw active; then
        ufw allow 80/tcp
    else
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    fi
    echo -e "${GREEN}WebSocket SSH activo en el puerto 80.${RESET}"
    pausa
}
detener_websocket() {
    pm2 stop websocket-ssh && echo -e "${YELLOW}WebSocket detenido.${RESET}"
    pausa
}
eliminar_websocket() {
    pm2 delete websocket-ssh
    rm -f ws-relax.js
    echo -e "${RED}WebSocket eliminado.${RESET}"
    pausa
}
estado_websocket() {
    clear; echo -e "${CYAN}=== Estado WebSocket SSH ===${RESET}"
    pm2 list | grep -q websocket-ssh && echo "WebSocket: online" || echo "WebSocket: offline"
    ss -tulpn | grep ':80' || echo "Puerto 80 no en escucha."
    pausa
}
submenu_websocket() {
    while true; do
        clear
        echo -e "${CYAN}==== WEBSOCKET SSH (RELAX) ====${RESET}"
        echo "1) Instalar WebSocket"
        echo "2) Detener WebSocket"
        echo "3) Eliminar WebSocket"
        echo "4) Estado WebSocket"
        echo "5) Volver"
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
    clear; echo -e "${CYAN}=== Estado servicios y puertos ===${RESET}"
    printf "SSH:        %s (Puertos: %s)\n" "$(systemctl is-active ssh 2>/dev/null)" "$(ss -tulpn | grep sshd | awk '{print $5}' | cut -d: -f2 | sort -u | xargs)"
    printf "Dropbear:   %s (Puertos: %s)\n" "$(systemctl is-active dropbear 2>/dev/null)" "$(ss -tulpn | grep dropbear | awk '{print $5}' | cut -d: -f2 | sort -u | xargs)"
    printf "BADVPN:     %s (UDP 7300)\n" "$(systemctl is-active badvpn-udpgw 2>/dev/null)"
    printf "Squid:      %s (Puertos: %s)\n" "$(systemctl is-active squid 2>/dev/null)" "$(ss -tulpn | grep squid | awk '{print $5}' | cut -d: -f2 | sort -u | xargs)"
    printf "Stunnel:    %s (Puertos: %s)\n" "$(systemctl is-active stunnel4 2>/dev/null)" "$(ss -tulpn | grep stunnel4 | awk '{print $5}' | cut -d: -f2 | sort -u | xargs)"
    printf "WebSocket:  %s (Puerto 80)\n" "$(pm2 list | grep -q websocket-ssh && echo online || echo offline)"
    pausa
}

# ---------- MENÚ PRINCIPAL ----------
while true; do
    clear
    echo -e "${CYAN}====== PANEL VPS EBX8 - MULTITOOL ======${RESET}"
    echo "1) Estado de servicios y puertos"
    echo "2) Gestión de usuarios SSH"
    echo "3) BADVPN UDPGW"
    echo "4) Dropbear SSH"
    echo "5) Squid Proxy"
    echo "6) Stunnel (TLS/SSL)"
    echo "7) WebSocket SSH (Relax)"
    echo "8) Abrir/cerrar puertos TCP"
    echo "9) Salir"
    read -p "Opción [1-9]: " mainopt
    case $mainopt in
        1) estado_servicios_inteligente ;;
        2) submenu_usuarios ;;
        3) submenu_badvpn ;;
        4) submenu_dropbear ;;
        5) submenu_squid ;;
        6) submenu_stunnel ;;
        7) submenu_websocket ;;
        8) abrir_puerto; cerrar_puerto ;;
        9) exit 0 ;;
        *) echo "Opción inválida." ; sleep 1 ;;
    esac
done

