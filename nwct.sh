#!/bin/bash
#
# Web 终端内网穿透一键部署脚本
# 工具: ttyd + bore
# 
# 使用方法:
#   chmod +x web-terminal-tunnel.sh
#   ./web-terminal-tunnel.sh
#
# 访问地址: http://bore.pub:端口号
# 用户名: admin
# 密码: Xmm0125..
#

set -e

# ==================== 配置区域 ====================
TTYD_PORT=7681                    # ttyd 本地端口
USERNAME="admin"                  # 登录用户名
PASSWORD="Xmm0125.."              # 登录密码
INSTALL_DIR="$HOME/.local/bin"    # 安装目录
# =================================================

echo "=========================================="
echo "   Web 终端内网穿透一键部署脚本"
echo "   工具: ttyd + bore"
echo "=========================================="
echo ""

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# ==================== 第一步：安装 ttyd ====================
echo "[1/4] 安装 ttyd (Web 终端)..."

if [ -f "$INSTALL_DIR/ttyd" ]; then
    echo "      ttyd 已安装，跳过"
else
    curl -L -o "$INSTALL_DIR/ttyd" "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"
    chmod +x "$INSTALL_DIR/ttyd"
    echo "      ttyd 安装完成: $($INSTALL_DIR/ttyd --version | head -1)"
fi

# ==================== 第二步：安装 bore ====================
echo "[2/4] 安装 bore (隧道工具)..."

if [ -f "$INSTALL_DIR/bore" ]; then
    echo "      bore 已安装，跳过"
else
    cd /tmp
    curl -L -o bore.tar.gz "https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf bore.tar.gz
    chmod +x bore
    mv bore "$INSTALL_DIR/"
    rm -f bore.tar.gz
    echo "      bore 安装完成: $($INSTALL_DIR/bore --version)"
fi

# ==================== 第三步：启动 ttyd ====================
echo "[3/4] 启动 ttyd 服务..."

# 停止已存在的 ttyd 进程
pkill -f "ttyd.*$TTYD_PORT" 2>/dev/null || true
sleep 1

# 启动 ttyd（带密码保护）
nohup "$INSTALL_DIR/ttyd" -p $TTYD_PORT --writable --credential "$USERNAME:$PASSWORD" bash > /tmp/ttyd.log 2>&1 &
sleep 2

# 检查是否启动成功
if ss -tlnp | grep -q ":$TTYD_PORT"; then
    echo "      ttyd 启动成功，监听端口: $TTYD_PORT"
else
    echo "      错误: ttyd 启动失败"
    cat /tmp/ttyd.log
    exit 1
fi

# ==================== 第四步：启动 bore 隧道 ====================
echo "[4/4] 启动 bore 隧道..."

# 停止已存在的 bore 进程
pkill -f "bore local" 2>/dev/null || true
sleep 1

# 启动 bore 隧道
nohup "$INSTALL_DIR/bore" local $TTYD_PORT --to bore.pub > /tmp/bore.log 2>&1 &
sleep 5

# 获取公网端口
PUBLIC_PORT=$(grep -oP 'remote_port=\K\d+' /tmp/bore.log 2>/dev/null || grep -oP 'listening at bore.pub:\K\d+' /tmp/bore.log 2>/dev/null)

if [ -n "$PUBLIC_PORT" ]; then
    echo "      bore 隧道启动成功"
else
    echo "      等待隧道建立..."
    sleep 3
    PUBLIC_PORT=$(grep -oP 'remote_port=\K\d+' /tmp/bore.log 2>/dev/null || grep -oP 'listening at bore.pub:\K\d+' /tmp/bore.log 2>/dev/null)
fi

# ==================== 完成 ====================
echo ""
echo "=========================================="
echo "   ✅ 部署完成！"
echo "=========================================="
echo ""
echo "🌐 公网访问地址: http://bore.pub:$PUBLIC_PORT"
echo "🔐 用户名: $USERNAME"
echo "🔑 密码: $PASSWORD"
echo ""
echo "📝 日志文件:"
echo "   - ttyd: /tmp/ttyd.log"
echo "   - bore: /tmp/bore.log"
echo ""
echo "🛑 停止服务:"
echo "   pkill -f ttyd; pkill -f bore"
echo ""
