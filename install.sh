#!/bin/bash
set -e

# BEpusdt 一键安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/hakimi-x/BEpusdt/main/install.sh | bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bepusdt"
BIN_PATH="/usr/local/bin/bepusdt"
SERVICE_FILE="/etc/systemd/system/bepusdt.service"
GITHUB_REPO="hakimi-x/BEpusdt"
DATA_DIR="/var/lib/bepusdt"
LOG_FILE="/var/log/bepusdt.log"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
    fi
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) log_error "不支持的架构: $ARCH" ;;
    esac
    
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$OS" != "linux" ]; then
        log_error "此脚本仅支持 Linux 系统"
    fi
    
    log_info "检测到系统: ${OS}-${ARCH}"
}

get_latest_version() {
    log_info "获取最新版本..."
    VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        log_error "无法获取最新版本"
    fi
    log_info "最新版本: $VERSION"
}

download_binary() {
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${OS}-${ARCH}-BEpusdt.tar.gz"
    TMP_DIR=$(mktemp -d)
    
    log_info "下载 $DOWNLOAD_URL ..."
    curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/bepusdt.tar.gz" || log_error "下载失败"
    
    log_info "解压文件..."
    tar -xzf "${TMP_DIR}/bepusdt.tar.gz" -C "$TMP_DIR"
    
    # 安装二进制
    install -m 755 "${TMP_DIR}/bepusdt" "$BIN_PATH"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    
    # 复制配置文件（如果不存在）
    if [ ! -f "${INSTALL_DIR}/conf.toml" ]; then
        if [ -f "${TMP_DIR}/conf.example.toml" ]; then
            cp "${TMP_DIR}/conf.example.toml" "${INSTALL_DIR}/conf.toml"
        else
            create_default_config
        fi
        log_warn "请编辑配置文件: ${INSTALL_DIR}/conf.toml"
    else
        log_info "配置文件已存在，跳过"
    fi
    
    rm -rf "$TMP_DIR"
    log_info "二进制安装完成: $BIN_PATH"
}

create_default_config() {
    cat > "${INSTALL_DIR}/conf.toml" << 'EOF'
app_uri = ""
auth_token = "CHANGE_ME"
listen = ":8080"
static_path = ""
sqlite_path = "/var/lib/bepusdt/sqlite.db"
tron_grpc_node = "18.141.79.38:50051"
output_log = "/var/log/bepusdt.log"
webhook_url = ""

[pay]
usdt_atom = 0.01
usdc_atom = 0.01
usdt_rate = "~0.98"
usdc_rate = "~0.98"
trx_atom = 0.01
trx_rate = "~0.95"
expire_time = 1200
wallet_address = []
trade_is_confirmed = false
payment_amount_min = 0.01
payment_amount_max = 99999

[evm_rpc]
bsc = "https://bsc-dataseed.bnbchain.org/"
polygon = "https://polygon-rpc.com/"
arbitrum = "https://arb1.arbitrum.io/rpc"
ethereum = "https://ethereum.publicnode.com/"
base = "https://base-public.nodies.app/"

[bot]
admin_id = 0
group_id = ""
token = ""
EOF
}

install_service() {
    log_info "安装 systemd 服务..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=BEpusdt Service
Documentation=https://github.com/${GITHUB_REPO}
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=${BIN_PATH} -conf ${INSTALL_DIR}/conf.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable bepusdt
    log_info "服务安装完成"
}

start_service() {
    log_info "启动服务..."
    systemctl start bepusdt || log_warn "启动失败，请检查配置文件"
    sleep 2
    if systemctl is-active --quiet bepusdt; then
        log_info "服务启动成功"
    else
        log_warn "服务未能启动，请检查: journalctl -u bepusdt -f"
    fi
}

show_info() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}BEpusdt 安装完成!${NC}"
    echo "=========================================="
    echo "配置文件: ${INSTALL_DIR}/conf.toml"
    echo "数据目录: ${DATA_DIR}"
    echo "日志文件: ${LOG_FILE}"
    echo ""
    echo "常用命令:"
    echo "  启动: systemctl start bepusdt"
    echo "  停止: systemctl stop bepusdt"
    echo "  重启: systemctl restart bepusdt"
    echo "  状态: systemctl status bepusdt"
    echo "  日志: journalctl -u bepusdt -f"
    echo ""
    echo -e "${YELLOW}请先编辑配置文件后再启动服务${NC}"
    echo "  nano ${INSTALL_DIR}/conf.toml"
    echo "=========================================="
}

uninstall() {
    log_info "卸载 BEpusdt..."
    systemctl stop bepusdt 2>/dev/null || true
    systemctl disable bepusdt 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    rm -f "$BIN_PATH"
    systemctl daemon-reload
    log_info "卸载完成（配置和数据已保留）"
    log_info "如需完全删除: rm -rf ${INSTALL_DIR} ${DATA_DIR} ${LOG_FILE}"
}

main() {
    case "${1:-install}" in
        install)
            check_root
            detect_arch
            get_latest_version
            download_binary
            install_service
            show_info
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        *)
            echo "用法: $0 [install|uninstall]"
            exit 1
            ;;
    esac
}

main "$@"
