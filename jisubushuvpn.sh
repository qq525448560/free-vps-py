#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# 生成30000-50000之间的随机端口
generate_random_port() {
    local min_port=30000
    local max_port=50000
    if command -v python3 &> /dev/null; then
        python3 -c "import random; print(random.randint($min_port, $max_port))"
    elif command -v shuf &> /dev/null; then
        shuf -i ${min_port}-${max_port} -n 1
    else
        # 使用 $RANDOM 生成随机数
        echo $(( (RANDOM % (max_port - min_port + 1)) + min_port ))
    fi
}

clear

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 一键部署脚本    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo -e "${BLUE}脚本仓库: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"
echo -e "${BLUE}TG交流群: ${YELLOW}https://t.me/+ft-zI76oovgwNmRh${NC}"
echo
echo -e "${GREEN}本脚本基于 eooce 大佬的 Python Xray Argo 项目开发${NC}"
echo -e "${GREEN}提供极速和完整两种配置模式，简化部署流程${NC}"
echo -e "${GREEN}支持自动UUID生成、后台运行、节点信息输出${NC}"
echo -e "${GREEN}支持交互式查看节点信息${NC}"
echo

MODE_CHOICE="1"
echo -e "${GREEN}自动选择极速模式${NC}"

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

# 使用Python进行配置替换（更可靠）
update_app_config() {
    python3 << 'PYEOF'
import re

# 读取配置参数
import sys
config_lines = sys.stdin.read().strip().split('\n')
configs = {}
for line in config_lines:
    if '=' in line:
        key, value = line.split('=', 1)
        configs[key.strip()] = value.strip()

# 读取app.py
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 替换UUID - 格式: UUID = os.environ.get('UUID', 'xxx')
if 'UUID' in configs:
    pattern = r"(UUID = os\.environ\.get\('UUID', ')[^']*('\))"
    replacement = r"\g<1>" + configs['UUID'] + r"\g<2>"
    content = re.sub(pattern, replacement, content)

# 替换CFIP - 格式: CFIP = os.environ.get('CFIP', 'xxx')
if 'CFIP' in configs:
    pattern = r"(CFIP = os\.environ\.get\('CFIP', ')[^']*('\))"
    replacement = r"\g<1>" + configs['CFIP'] + r"\g<2>"
    content = re.sub(pattern, replacement, content)

# 替换PORT - 格式: PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or 3000)
if 'PORT' in configs:
    pattern = r"(PORT = int\(os\.environ\.get\('SERVER_PORT'\) or os\.environ\.get\('PORT'\) or )\d+"
    replacement = r"\g<1>" + configs['PORT']
    content = re.sub(pattern, replacement, content)

# 替换NAME - 格式: NAME = os.environ.get('NAME', 'xxx')
if 'NAME' in configs:
    pattern = r"(NAME = os\.environ\.get\('NAME', ')[^']*('\))"
    replacement = r"\g<1>" + configs['NAME'] + r"\g<2>"
    content = re.sub(pattern, replacement, content)

# 替换CFPORT - 格式: CFPORT = int(os.environ.get('CFPORT', '443'))
if 'CFPORT' in configs:
    pattern = r"(CFPORT = int\(os\.environ\.get\('CFPORT', ')[^']*('\)\))"
    replacement = r"\g<1>" + configs['CFPORT'] + r"\g<2>"
    content = re.sub(pattern, replacement, content)

# 替换SUB_PATH - 格式: SUB_PATH = os.environ.get('SUB_PATH', 'xxx')
if 'SUB_PATH' in configs:
    pattern = r"(SUB_PATH = os\.environ\.get\('SUB_PATH', ')[^']*('\))"
    replacement = r"\g<1>" + configs['SUB_PATH'] + r"\g<2>"
    content = re.sub(pattern, replacement, content)

# 写回文件
with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("配置更新完成")
PYEOF
}

if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    echo
    
    UUID_INPUT="e258977b-e413-4718-a3af-02d75492c349"
    echo -e "${GREEN}使用固定UUID: $UUID_INPUT${NC}"
    
    # 生成随机端口（30000-50000）
    RANDOM_PORT=$(generate_random_port)
    echo -e "${GREEN}生成随机端口: $RANDOM_PORT${NC}"
    
    # 使用Python更新配置
    echo -e "UUID=$UUID_INPUT\nCFIP=joeyblog.net\nPORT=$RANDOM_PORT" | update_app_config
    
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    echo -e "${GREEN}优选IP已自动设置为: joeyblog.net${NC}"
    echo -e "${GREEN}服务端口已设置为: $RANDOM_PORT${NC}"
    
    echo
    echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
    echo
    
else
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    # 获取当前UUID值（使用-f4获取第二个单引号对中的值）
    CURRENT_UUID=$(grep "^UUID = " app.py | head -1 | cut -d"'" -f4)
    echo -e "${YELLOW}当前UUID: $CURRENT_UUID${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi

    # 获取当前节点名称
    CURRENT_NAME=$(grep "^NAME = " app.py | head -1 | cut -d"'" -f4)
    echo -e "${YELLOW}当前节点名称: $CURRENT_NAME${NC}"
    read -p "请输入节点名称 (留空保持不变): " NAME_INPUT

    # 获取当前服务端口
    CURRENT_PORT=$(grep "^PORT = " app.py | grep -oE "or [0-9]+" | tail -1 | cut -d" " -f2)
    echo -e "${YELLOW}当前服务端口: $CURRENT_PORT${NC}"
    read -p "请输入服务端口 (留空使用随机端口30000-50000): " PORT_INPUT
    if [ -z "$PORT_INPUT" ]; then
        PORT_INPUT=$(generate_random_port)
        echo -e "${GREEN}自动生成随机端口: $PORT_INPUT${NC}"
    fi

    # 获取当前优选IP
    CURRENT_CFIP=$(grep "^CFIP = " app.py | head -1 | cut -d"'" -f4)
    echo -e "${YELLOW}当前优选IP: $CURRENT_CFIP${NC}"
    read -p "请输入优选IP/域名 (留空使用默认 34.92.248.117): " CFIP_INPUT
    if [ -z "$CFIP_INPUT" ]; then
        CFIP_INPUT="34.92.248.117"
    fi

    # 获取当前优选端口
    CURRENT_CFPORT=$(grep "^CFPORT = " app.py | head -1 | cut -d"'" -f4)
    echo -e "${YELLOW}当前优选端口: $CURRENT_CFPORT${NC}"
    read -p "请输入优选端口 (留空保持不变): " CFPORT_INPUT

    # 获取当前订阅路径
    CURRENT_SUB_PATH=$(grep "^SUB_PATH = " app.py | head -1 | cut -d"'" -f4)
    echo -e "${YELLOW}当前订阅路径: $CURRENT_SUB_PATH${NC}"
    read -p "请输入订阅路径 (留空保持不变): " SUB_PATH_INPUT

    # 构建配置更新输入
    CONFIG_INPUT="UUID=$UUID_INPUT\nPORT=$PORT_INPUT\nCFIP=$CFIP_INPUT"
    if [ -n "$NAME_INPUT" ]; then
        CONFIG_INPUT="$CONFIG_INPUT\nNAME=$NAME_INPUT"
    fi
    if [ -n "$CFPORT_INPUT" ]; then
        CONFIG_INPUT="$CONFIG_INPUT\nCFPORT=$CFPORT_INPUT"
    fi
    if [ -n "$SUB_PATH_INPUT" ]; then
        CONFIG_INPUT="$CONFIG_INPUT\nSUB_PATH=$SUB_PATH_INPUT"
    fi

    # 更新配置
    echo -e "$CONFIG_INPUT" | update_app_config

    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    echo -e "${GREEN}端口已设置为: $PORT_INPUT${NC}"
    echo -e "${GREEN}优选IP已设置为: $CFIP_INPUT${NC}"
    if [ -n "$NAME_INPUT" ]; then
        echo -e "${GREEN}节点名称已设置为: $NAME_INPUT${NC}"
    fi
    if [ -n "$CFPORT_INPUT" ]; then
        echo -e "${GREEN}优选端口已设置为: $CFPORT_INPUT${NC}"
    fi
    if [ -n "$SUB_PATH_INPUT" ]; then
        echo -e "${GREEN}订阅路径已设置为: $SUB_PATH_INPUT${NC}"
    fi

    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        # 高级选项配置（保持原有逻辑）
        echo -e "${YELLOW}高级选项配置...${NC}"
        # 这里可以添加更多高级选项
    fi

    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

# 获取当前配置（使用正确的字段提取方式）
CURRENT_UUID=$(grep "^UUID = " app.py | head -1 | cut -d"'" -f4)
CURRENT_PORT=$(grep "^PORT = " app.py | grep -oE "or [0-9]+" | tail -1 | cut -d" " -f2)
CURRENT_CFIP=$(grep "^CFIP = " app.py | head -1 | cut -d"'" -f4)
CURRENT_CFPORT=$(grep "^CFPORT = " app.py | head -1 | cut -d"'" -f4)
CURRENT_SUB_PATH=$(grep "^SUB_PATH = " app.py | head -1 | cut -d"'" -f4)
CURRENT_NAME=$(grep "^NAME = " app.py | head -1 | cut -d"'" -f4)

echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $CURRENT_UUID"
echo -e "节点名称: $CURRENT_NAME"
echo -e "服务端口: $CURRENT_PORT"
echo -e "优选IP: $CURRENT_CFIP"
echo -e "优选端口: $CURRENT_CFPORT"
echo -e "订阅路径: $CURRENT_SUB_PATH"
echo -e "${YELLOW}========================${NC}"
echo

# 添加CF节点分流配置（YouTube流量走CF边缘节点）
echo -e "${BLUE}正在添加CF节点分流配置...${NC}"

cat > cf_patch.py << 'PYEOF'
import re
import sys

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines(keepends=True)

# CF节点分流配置代码（无前导空格，避免缩进错误）
CF_OUTBOUND_CODE = '''# ===== CF节点分流配置（自动注入）=====
config['outbounds'] = [
    {'protocol': 'freedom', 'tag': 'direct'},
    {
        'protocol': 'vless', 'tag': 'cf-hk',
        'settings': {'vnext': [{'address': 'hj.xmm1993.top', 'port': 443,
            'users': [{'id': '88d66d66-740f-479d-86e3-29a1dfea6aa8', 'encryption': 'none'}]}]},
        'streamSettings': {
            'network': 'ws', 'security': 'tls',
            'tlsSettings': {'serverName': 'sj-8d4.pages.dev', 'allowInsecure': True, 'fingerprint': 'chrome'},
            'wsSettings': {'path': '/ads/shop/wenku/proxyip=tw.x9527.xyz?ed=2560', 'headers': {'Host': 'sj-8d4.pages.dev'}}
        }
    },
    {'protocol': 'blackhole', 'tag': 'block'}
]
config['routing'] = {
    'domainStrategy': 'IPIfNonMatch',
    'rules': [{'type': 'field',
        'domain': ['youtube.com', 'googlevideo.com', 'ytimg.com', 'gstatic.com',
                   'googleapis.com', 'ggpht.com', 'googleusercontent.com'],
        'outboundTag': 'cf-hk'}]
}
# ===== CF节点分流配置结束 =====

'''

inject_after = -1

# 策略1: 单行 config 含 outbounds（单引号或双引号均可）
for i, line in enumerate(lines):
    if re.search(r'\bconfig\s*=', line) and 'outbounds' in line:
        inject_after = i
        print(f"[策略1] 在第 {i+1} 行找到 config（含outbounds）")
        break

# 策略2: 单行 config 含 inbounds
if inject_after == -1:
    for i, line in enumerate(lines):
        if re.search(r'\bconfig\s*=', line) and 'inbounds' in line:
            inject_after = i
            print(f"[策略2] 在第 {i+1} 行找到 config（含inbounds）")
            break

# 策略3: 找到 config = { 开头，追踪大括号深度找到 config 定义结束行
if inject_after == -1:
    config_start = -1
    for i, line in enumerate(lines):
        if re.search(r'\bconfig\s*=\s*\{', line):
            config_start = i
            break
    if config_start >= 0:
        depth = 0
        for i in range(config_start, len(lines)):
            depth += lines[i].count('{') - lines[i].count('}')
            if depth == 0 and i > config_start:
                inject_after = i
                print(f"[策略3] config 定义结束于第 {i+1} 行")
                break

# 策略4: 在 json.dump(config 之前注入
if inject_after == -1:
    for i, line in enumerate(lines):
        if 'json.dump' in line and 'config' in line:
            inject_after = i - 1
            print(f"[策略4] 在 json.dump 前（第 {i} 行）注入")
            break

# 策略5: 找到启动 xray 的行之前注入
if inject_after == -1:
    for i, line in enumerate(lines):
        if 'xray' in line.lower() and ('Popen' in line or 'run' in line or 'config' in line):
            inject_after = i - 1
            print(f"[策略5] 在 xray 启动前（第 {i} 行）注入")
            break

if inject_after < 0:
    print("错误: 所有策略均未能定位 config，输出 app.py 前50行供排查：")
    for i, line in enumerate(lines[:50]):
        print(f"{i+1:3d}: {line}", end='')
    sys.exit(1)

lines.insert(inject_after + 1, CF_OUTBOUND_CODE)
with open('app.py', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print(f"CF节点分流配置已成功注入（第 {inject_after+1} 行后）")
PYEOF

python3 cf_patch.py
if [ $? -ne 0 ]; then
    echo -e "${RED}CF分流配置注入失败，请查看上方错误信息${NC}"
    exit 1
fi
rm cf_patch.py
echo -e "${GREEN}CF节点分流已集成（YouTube → 香港CF节点）${NC}"
echo

echo -e "${BLUE}正在启动服务...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"
echo

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
    echo -e "${YELLOW}检查端口占用: netstat -tlnp | grep :$CURRENT_PORT${NC}"
    exit 1
fi

echo -e "${GREEN}服务运行正常${NC}"

SERVICE_PORT=$CURRENT_PORT
SUB_PATH_VALUE=$CURRENT_SUB_PATH

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

echo -e "${GREEN}订阅链接:${NC}"
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
查看进程: ps aux | grep python3"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}使用脚本选择选项3可随时查看节点信息${NC}"

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}部署已完成，节点信息已成功生成${NC}"
echo -e "${GREEN}可以立即使用订阅地址添加到客户端${NC}"
echo -e "${GREEN}服务将持续在后台运行${NC}"
echo

echo -e "${GREEN}部署完成！感谢使用！${NC}"

# 退出脚本，避免重复执行
exit 0
