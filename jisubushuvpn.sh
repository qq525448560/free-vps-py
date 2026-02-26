#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"

# 如果是-v参数，直接查看节点信息
if [ "$1" = "-v" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}           节点信息查看               ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
    else
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
    fi
    exit 0
fi

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

clear

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 极速一键部署    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo

# 自动选择极速模式
MODE_CHOICE="1"
echo -e "${GREEN}已自动选择：极速模式${NC}"
echo

echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/python-xray-argo.git
    else
        echo -e "${YELLOW}Git未安装，使用wget下载...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O python-xray-argo.zip
        if command -v unzip &> /dev/null; then
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        else
            echo -e "${YELLOW}正在安装 unzip...${NC}"
            sudo apt-get install -y unzip
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        fi
    fi
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

echo -e "${GREEN}依赖安装完成！${NC}"
echo

if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

cp app.py app.py.backup
echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"

echo -e "${BLUE}=== 极速模式 ===${NC}"
echo

# 使用固定UUID
UUID_INPUT="e258977b-e413-4718-a3af-02d75492c349"
echo -e "${GREEN}使用固定UUID: $UUID_INPUT${NC}"

sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"

sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
echo -e "${GREEN}优选IP已自动设置为: joeyblog.net${NC}"
echo -e "${GREEN}YouTube分流已自动配置${NC}"

echo
echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
echo

echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"
echo -e "${YELLOW}========================${NC}"
echo

echo -e "${BLUE}正在启动服务...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"
echo

# 修改Python文件添加YouTube分流到xray配置，并增加80端口节点
echo -e "${BLUE}正在添加YouTube分流功能和80端口节点...${NC}"
cat > youtube_patch.py << 'EOF'
# 读取app.py文件
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 找到原始配置并替换为包含YouTube分流的配置
old_config = 'config ={"log":{"access":"/dev/null","error":"/dev/null","loglevel":"none",},"inbounds":[{"port":ARGO_PORT ,"protocol":"vless","settings":{"clients":[{"id":UUID ,"flow":"xtls-rprx-vision",},],"decryption":"none","fallbacks":[{"dest":3001 },{"path":"/vless-argo","dest":3002 },{"path":"/vmess-argo","dest":3003 },{"path":"/trojan-argo","dest":3004 },],},"streamSettings":{"network":"tcp",},},{"port":3001 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID },],"decryption":"none"},"streamSettings":{"network":"ws","security":"none"}},{"port":3002 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID ,"level":0 }],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3003 ,"listen":"127.0.0.1","protocol":"vmess","settings":{"clients":[{"id":UUID ,"alterId":0 }]},"streamSettings":{"network":"ws","wsSettings":{"path":"/vmess-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3004 ,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":UUID },]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},],"outbounds":[{"protocol":"freedom","tag": "direct" },{"protocol":"blackhole","tag":"block"}]}'

new_config = '''config = {
        "log": {
            "access": "/dev/null",
            "error": "/dev/null",
            "loglevel": "none"
        },
        "inbounds": [
            {
                "port": ARGO_PORT,
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "flow": "xtls-rprx-vision"}],
                    "decryption": "none",
                    "fallbacks": [
                        {"dest": 3001},
                        {"path": "/vless-argo", "dest": 3002},
                        {"path": "/vmess-argo", "dest": 3003},
                        {"path": "/trojan-argo", "dest": 3004}
                    ]
                },
                "streamSettings": {"network": "tcp"}
            },
            {
                "port": 3001,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID}],
                    "decryption": "none"
                },
                "streamSettings": {"network": "ws", "security": "none"}
            },
            {
                "port": 3002,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "level": 0}],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/vless-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3003,
                "listen": "127.0.0.1",
                "protocol": "vmess",
                "settings": {
                    "clients": [{"id": UUID, "alterId": 0}]
                },
                "streamSettings": {
                    "network": "ws",
                    "wsSettings": {"path": "/vmess-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3004,
                "listen": "127.0.0.1",
                "protocol": "trojan",
                "settings": {
                    "clients": [{"password": UUID}]
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/trojan-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            }
        ],
        "outbounds": [
            {"protocol": "freedom", "tag": "direct"},
            {
                "protocol": "vmess",
                "tag": "youtube",
                "settings": {
                    "vnext": [{
                        "address": "172.233.171.224",
                        "port": 16416,
                        "users": [{
                            "id": "8c1b9bea-cb51-43bb-a65c-0af31bbbf145",
                            "alterId": 0
                        }]
                    }]
                },
                "streamSettings": {"network": "tcp"}
            },
            {"protocol": "blackhole", "tag": "block"}
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {
                    "type": "field",
                    "domain": [
                        "youtube.com",
                        "googlevideo.com",
                        "ytimg.com",
                        "gstatic.com",
                        "googleapis.com",
                        "ggpht.com",
                        "googleusercontent.com"
                    ],
                    "outboundTag": "youtube"
                }
            ]
        }
    }'''

# 替换配置
content = content.replace(old_config, new_config)

# 修改generate_links函数，添加80端口节点
old_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    VMESS = {"v": "2", "ps": f"{NAME}-{ISP}", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}
  
vmess://{ base64.b64encode(json.dumps(VMESS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    # Additional actions
    send_telegram()
    upload_nodes()
  
    return sub_txt'''

new_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    
    # TLS节点 (443端口)
    VMESS_TLS = {"v": "2", "ps": f"{NAME}-{ISP}-TLS", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
    
    # 无TLS节点 (80端口)
    VMESS_80 = {"v": "2", "ps": f"{NAME}-{ISP}-80", "add": CFIP, "port": "80", "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "", "sni": "", "alpn": "", "fp": ""}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-TLS
  
vmess://{ base64.b64encode(json.dumps(VMESS_TLS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-TLS

vless://{UUID}@{CFIP}:80?encryption=none&security=none&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-80

vmess://{ base64.b64encode(json.dumps(VMESS_80).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:80?security=none&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-80
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    # Additional actions
    send_telegram()
    upload_nodes()
  
    return sub_txt'''

# 替换generate_links函数
content = content.replace(old_generate_function, new_generate_function)

# 写回文件
with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("YouTube分流配置和80端口节点已成功添加")
EOF

python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}YouTube分流和80端口节点已集成${NC}"

# 先清理可能存在的进程
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

# 启动服务并获取PID
python3 app.py > app.log 2>&1 &
APP_PID=$!

# 验证PID获取成功
if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${RED}获取进程PID失败，尝试直接启动${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
    if [ -z "$APP_PID" ]; then
        echo -e "${RED}服务启动失败，请检查Python环境${NC}"
        echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"
echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"

echo -e "${BLUE}等待服务启动...${NC}"
sleep 8

# 检查服务是否正常运行
if ! ps -p "$APP_PID" > /dev/null 2>&1; then
    echo -e "${RED}服务启动失败，请检查日志${NC}"
    echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
    echo -e "${YELLOW}检查端口占用: netstat -tlnp | grep :3000${NC}"
    exit 1
fi

echo -e "${GREEN}服务运行正常${NC}"

SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
CURRENT_UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
SUB_PATH_VALUE=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

echo -e "${BLUE}等待节点信息生成...${NC}"
echo -e "${YELLOW}正在等待Argo隧道建立和节点生成，请耐心等待...${NC}"

# 循环等待节点信息生成，最多等待10分钟
MAX_WAIT=600  # 10分钟
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    fi
    
    # 每30秒显示一次等待提示
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        MINUTES=$((WAIT_COUNT / 60))
        SECONDS=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}已等待 ${MINUTES}分${SECONDS}秒，继续等待节点生成...${NC}"
        echo -e "${BLUE}提示: Argo隧道建立需要时间，请继续等待${NC}"
    fi
    
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

# 检查是否成功获取到节点信息
if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}等待超时！节点信息未能在10分钟内生成${NC}"
    echo -e "${YELLOW}可能原因：${NC}"
    echo -e "1. 网络连接问题"
    echo -e "2. Argo隧道建立失败"
    echo -e "3. 服务配置错误"
    echo
    echo -e "${BLUE}建议操作：${NC}"
    echo -e "1. 查看日志: ${YELLOW}tail -f $(pwd)/app.log${NC}"
    echo -e "2. 检查服务: ${YELLOW}ps aux | grep python3${NC}"
    echo -e "3. 重新运行脚本"
    echo
    echo -e "${YELLOW}服务信息：${NC}"
    echo -e "进程PID: ${BLUE}$APP_PID${NC}"
    echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
    echo -e "日志文件: ${YELLOW}$(pwd)/app.log${NC}"
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== 服务信息 ===${NC}"
echo -e "服务状态: ${GREEN}运行中${NC}"
echo -e "进程PID: ${BLUE}$APP_PID${NC}"
echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
echo -e "UUID: ${BLUE}$CURRENT_UUID${NC}"
echo -e "订阅路径: ${BLUE}/$SUB_PATH_VALUE${NC}"
echo

echo -e "${YELLOW}=== 访问地址 ===${NC}"
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "获取失败")
    if [ "$PUBLIC_IP" != "获取失败" ]; then
        echo -e "订阅地址: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
        echo -e "管理面板: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT${NC}"
    fi
fi
echo -e "本地订阅: ${GREEN}http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
echo -e "本地面板: ${GREEN}http://localhost:$SERVICE_PORT${NC}"
echo

echo -e "${YELLOW}=== 节点信息 ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")

echo -e "${GREEN}节点配置:${NC}"
echo "$DECODED_NODES"
echo

echo -e "${GREEN}订阅链接(Base64):${NC}"
echo "$NODE_INFO"
echo

SAVE_INFO="========================================
           节点信息保存               
========================================

部署时间: $(date)
UUID: $CURRENT_UUID
服务端口: $SERVICE_PORT
订阅路径: /$SUB_PATH_VALUE

=== 访问地址 ==="

if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "获取失败")
    if [ "$PUBLIC_IP" != "获取失败" ]; then
        SAVE_INFO="${SAVE_INFO}
订阅地址: http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE
管理面板: http://$PUBLIC_IP:$SERVICE_PORT"
    fi
fi

SAVE_INFO="${SAVE_INFO}
本地订阅: http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE
本地面板: http://localhost:$SERVICE_PORT

=== 节点信息 ===
$DECODED_NODES

=== 订阅链接 ===
$NODE_INFO

=== 管理命令 ===
查看日志: tail -f $(pwd)/app.log
停止服务: kill $APP_PID
重启服务: kill $APP_PID && nohup python3 app.py > app.log 2>&1 &
查看进程: ps aux | grep python3

=== 分流说明 ===
- 已集成YouTube分流优化到xray配置
- YouTube相关域名自动走专用线路
- 无需额外配置，透明分流"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}再次查看节点信息: bash $0 -v${NC}"

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}部署已完成，节点信息已成功生成${NC}"
echo -e "${GREEN}可以立即使用订阅地址添加到客户端${NC}"
echo -e "${GREEN}YouTube分流已集成到xray配置，无需额外设置${NC}"
echo -e "${GREEN}服务将持续在后台运行${NC}"
echo

echo -e "${GREEN}部署完成！感谢使用！${NC}"

# 退出脚本，避免重复执行
exit 0
