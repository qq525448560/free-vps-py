#!/bin/bash
# deploy_ssr.sh
# 一键部署 ShadowsocksR (SSR) 服务端（systemd）
# 适用于 Debian/Ubuntu 系统；其他 Linux 发行版可能需要调整包管理命令
# 作者: x-aniu
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/shadowsocksrr/shadowsocksr.git"
INSTALL_DIR="/opt/shadowsocksr"
CONFIG_FILE="${INSTALL_DIR}/user-config.json"
SERVICE_NAME="ssr-server"
PYTHON_BIN="$(command -v python3 || command -v python || true)"
OS=""
PKG_INSTALL=""

function echo_err { echo -e "${RED}$*${NC}"; }
function echo_ok { echo -e "${GREEN}$*${NC}"; }
function echo_warn { echo -e "${YELLOW}$*${NC}"; }
function require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_err "请使用 root 权限运行此脚本（sudo）。"
        exit 1
    fi
}

function detect_os_and_install_cmd() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_INSTALL="apt-get install -y"
        apt-get update
    elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_INSTALL="yum install -y"
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
        PKG_INSTALL="apk add --no-cache"
    else
        OS="unknown"
        PKG_INSTALL="apt-get install -y"
    fi
}

function install_dependencies() {
    echo -e "${BLUE}检查并安装依赖...${NC}"
    detect_os_and_install_cmd

    if ! command -v git >/dev/null 2>&1; then
        echo_warn "正在安装 git..."
        $PKG_INSTALL git || { echo_err "安装 git 失败，请手动安装"; exit 1; }
    fi

    if ! command -v $PYTHON_BIN >/dev/null 2>&1; then
        echo_warn "未找到 python3，尝试安装..."
        if [ "$OS" = "debian" ]; then
            apt-get update
            apt-get install -y python3 python3-pip
        elif [ "$OS" = "centos" ]; then
            yum install -y python3 python3-pip
        elif [ "$OS" = "alpine" ]; then
            apk add --no-cache python3 py3-pip
        else
            apt-get update
            apt-get install -y python3 python3-pip
        fi
        PYTHON_BIN="$(command -v python3 || command -v python || true)"
    fi

    if ! command -v pip3 >/dev/null 2>&1; then
        echo_warn "未找到 pip3，尝试安装..."
        if [ "$OS" = "debian" ]; then
            apt-get install -y python3-pip
        elif [ "$OS" = "centos" ]; then
            yum install -y python3-pip
        elif [ "$OS" = "alpine" ]; then
            apk add --no-cache py3-pip
        else
            apt-get install -y python3-pip
        fi
    fi

    # 安装依赖库（requests 通常被 SSR 工具用到）
    pip3 install --no-cache-dir -U pip || true
    pip3 install --no-cache-dir -U requests || true
}

function clone_repo() {
    if [ -d "$INSTALL_DIR" ]; then
        echo_warn "$INSTALL_DIR 已存在，先备份旧目录为 ${INSTALL_DIR}_bak_$(date +%s)"
        mv "$INSTALL_DIR" "${INSTALL_DIR}_bak_$(date +%s)"
    fi

    echo_ok "克隆 ShadowsocksR 仓库到 $INSTALL_DIR ..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" || {
        echo_warn "git clone 失败，尝试使用 wget 下载 zip..."
        tmpzip="/tmp/ssr_repo_$(date +%s).zip"
        wget -q -O "$tmpzip" "https://github.com/shadowsocksrr/shadowsocksr/archive/refs/heads/master.zip" || { echo_err "下载失败"; exit 1; }
        unzip -q "$tmpzip" -d /opt || { echo_err "unzip 失败"; exit 1; }
        mv /opt/shadowsocksr-master "$INSTALL_DIR"
        rm -f "$tmpzip"
    }
}

function read_user_input() {
    echo
    echo -e "${BLUE}请输入 SSR 服务配置（回车使用推荐值）${NC}"
    read -p "监听端口 (默认 8388): " SSR_PORT
    SSR_PORT=${SSR_PORT:-8388}
    read -p "密码 (默认 auto 随机): " SSR_PASS
    if [ -z "$SSR_PASS" ]; then
        SSR_PASS="$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)"
        echo_ok "已生成密码: $SSR_PASS"
    fi

    echo -e "${YELLOW}请选择加密方式（method），常用: aes-256-cfb chacha20-ietf chacha20-ietf-poly1305${NC}"
    read -p "method (默认 aes-256-cfb): " SSR_METHOD
    SSR_METHOD=${SSR_METHOD:-aes-256-cfb}

    echo -e "${YELLOW}请选择协议 (protocol)，常用: auth_sha1_v4 auth_aes128_md5${NC}"
    read -p "protocol (默认 auth_sha1_v4): " SSR_PROTOCOL
    SSR_PROTOCOL=${SSR_PROTOCOL:-auth_sha1_v4}

    echo -e "${YELLOW}请选择混淆 (obfs)，常用: tls1.2_ticket_auth http_simple random_head${NC}"
    read -p "obfs (默认 tls1.2_ticket_auth): " SSR_OBFS
    SSR_OBFS=${SSR_OBFS:-tls1.2_ticket_auth}

    read -p "连接超时 (秒, 默认 120): " SSR_TIMEOUT
    SSR_TIMEOUT=${SSR_TIMEOUT:-120}

    # 可选：节点名称（用于备注）
    read -p "节点备注 (可选): " SSR_REMARK
    SSR_REMARK=${SSR_REMARK:-SSR-Node}
}

function write_config() {
    mkdir -p "$INSTALL_DIR"
    cat > "$CONFIG_FILE" <<EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${SSR_PORT},
    "password": "${SSR_PASS}",
    "method": "${SSR_METHOD}",
    "protocol": "${SSR_PROTOCOL}",
    "protocol_param": "",
    "obfs": "${SSR_OBFS}",
    "obfs_param": "",
    "timeout": ${SSR_TIMEOUT},
    "redirect": "",
    "dns_ipv6": false,
    "fast_open": false,
    "workers": 1
}
EOF
    echo_ok "已生成配置文件: ${CONFIG_FILE}"
}

function create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    echo -e "${BLUE}创建 systemd 服务: $SERVICE_FILE${NC}"

    # 使用 shadowsocksr 里常见的 server.py 脚本来启动（如果 repo 结构不同，请调整 ExecStart）
    cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=ShadowsocksR Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${PYTHON_BIN} server.py
Restart=on-failure
RestartSec=5
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    sleep 1
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo_ok "服务已启动: systemctl status $SERVICE_NAME --no-pager"
    else
        echo_err "服务启动失败，请查看日志: journalctl -u $SERVICE_NAME -n 200 --no-pager"
        exit 1
    fi
}

function generate_ssr_link() {
    # SSR 链接格式：
    # ssr://Base64( server:port:protocol:method:obfs:base64(password)/?remarks=base64(remark) )
    SERVER_ADDR=$(curl -s --max-time 8 https://api.ipify.org || echo "")
    if [ -z "$SERVER_ADDR" ]; then
        # 取本机网卡 IP（非公网）作为占位
        SERVER_ADDR="$(hostname -I | awk '{print $1}')"
    fi

    # base64 encode helpers (urlsafe)
    b64() {
        python3 - <<PY
import sys,base64
s=sys.stdin.read().encode('utf-8')
print(base64.urlsafe_b64encode(s).decode('utf-8').strip('='))
PY
    }

    PWD_B64=$(printf "%s" "$SSR_PASS" | b64)
    REMARK_B64=$(printf "%s" "$SSR_REMARK" | b64)
    PAYLOAD="${SERVER_ADDR}:${SSR_PORT}:${SSR_PROTOCOL}:${SSR_METHOD}:${SSR_OBFS}:${PWD_B64}/?remarks=${REMARK_B64}"
    PAYLOAD_B64=$(printf "%s" "$PAYLOAD" | b64)
    SSR_LINK="ssr://${PAYLOAD_B64}"
    echo
    echo_ok "===== SSR 链接 ====="
    echo "$SSR_LINK"
    echo_ok "===== SSR 链接 (明文信息) ====="
    echo "服务器: $SERVER_ADDR"
    echo "端口: $SSR_PORT"
    echo "密码: $SSR_PASS"
    echo "method: $SSR_METHOD"
    echo "protocol: $SSR_PROTOCOL"
    echo "obfs: $SSR_OBFS"
    echo_ok "===================="
}

function print_usage_info() {
    echo
    echo -e "${GREEN}部署完成！常用管理命令：${NC}"
    echo -e "查看服务状态: ${YELLOW}systemctl status ${SERVICE_NAME} --no-pager${NC}"
    echo -e "查看日志: ${YELLOW}journalctl -u ${SERVICE_NAME} -n 200 --no-pager${NC}"
    echo -e "停止服务: ${YELLOW}systemctl stop ${SERVICE_NAME}${NC}"
    echo -e "启动服务: ${YELLOW}systemctl start ${SERVICE_NAME}${NC}"
    echo -e "重启服务: ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "配置文件: ${YELLOW}${CONFIG_FILE}${NC}"
    echo
}

### 主流程
require_root
install_dependencies
clone_repo
read_user_input
write_config

# 将配置文件放到 repo 的预期位置（不同 fork 位置不同，尝试常见位置）
# server.py 有些实现会读取 user-config.json 或 config.json
if [ -f "${INSTALL_DIR}/server.py" ]; then
    # ensure server.py uses user-config.json: many forks auto-load user-config.json in cwd
    cp "$CONFIG_FILE" "${INSTALL_DIR}/user-config.json" || true
fi

create_systemd_service

generate_ssr_link
print_usage_info

echo_ok "如果 systemd 启动失败，请运行: cd ${INSTALL_DIR} && ${PYTHON_BIN} server.py -c ${CONFIG_FILE} 来手动调试。"
