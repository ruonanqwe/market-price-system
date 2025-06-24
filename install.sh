#!/bin/bash

# 农产品市场价格监控系统安装脚本
# 适用于 ubuntu22.04-py311-torch2.3.1-1.27.0 环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本"
        exit 1
    fi
}

# 检查系统环境
check_environment() {
    log_step "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        log_warn "当前系统不是Ubuntu 22.04，可能存在兼容性问题"
    fi
    
    # 检查Python版本
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未安装"
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    if [[ "$PYTHON_VERSION" != "3.11" ]]; then
        log_warn "Python版本不是3.11，当前版本: $PYTHON_VERSION"
    fi
    
    # 检查pip
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 未安装"
        exit 1
    fi
    
    # 检查Docker（可选）
    if command -v docker &> /dev/null; then
        log_info "检测到Docker，支持容器化部署"
        DOCKER_AVAILABLE=true
    else
        log_warn "未检测到Docker，将使用本地部署"
        DOCKER_AVAILABLE=false
    fi
    
    log_info "环境检查完成"
}

# 安装系统依赖
install_system_dependencies() {
    log_step "安装系统依赖..."
    
    # 更新包列表
    sudo apt-get update
    
    # 安装必要的系统包
    sudo apt-get install -y \
        curl \
        wget \
        git \
        sqlite3 \
        libsqlite3-dev \
        python3-dev \
        python3-pip \
        python3-venv \
        build-essential \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        pkg-config
    
    log_info "系统依赖安装完成"
}

# 创建虚拟环境
create_virtual_environment() {
    log_step "创建Python虚拟环境..."
    
    VENV_DIR="$HOME/market-price-env"
    
    if [[ -d "$VENV_DIR" ]]; then
        log_warn "虚拟环境已存在，将重新创建"
        rm -rf "$VENV_DIR"
    fi
    
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # 升级pip
    pip install --upgrade pip
    
    log_info "虚拟环境创建完成: $VENV_DIR"
}

# 安装Python依赖
install_python_dependencies() {
    log_step "安装Python依赖包..."
    
    # 确保在虚拟环境中
    if [[ -z "$VIRTUAL_ENV" ]]; then
        source "$HOME/market-price-env/bin/activate"
    fi
    
    # 安装依赖
    pip install -r requirements.txt
    
    log_info "Python依赖安装完成"
}

# 创建应用目录结构
create_app_structure() {
    log_step "创建应用目录结构..."
    
    APP_DIR="$HOME/market-price-system"
    
    # 创建主目录
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    # 创建子目录
    mkdir -p data logs reports backups config
    
    # 复制应用文件
    cp ../market_crawler.py .
    cp ../api_server.py .
    cp ../database_manager.py .
    cp ../location_service.py .
    cp ../scheduler_service.py .
    cp ../requirements.txt .
    
    # 创建配置文件
    cat > config/app_config.json << EOF
{
    "app_name": "农产品市场价格监控系统",
    "version": "1.0.0",
    "api_host": "0.0.0.0",
    "api_port": 8000,
    "db_path": "data/market_data.db",
    "log_level": "INFO",
    "data_retention_days": 90,
    "crawl_interval_minutes": 30,
    "enable_notifications": false,
    "notification_webhook": ""
}
EOF
    
    # 创建调度器配置
    cat > scheduler_config.json << EOF
{
    "crawl_interval_minutes": 30,
    "cleanup_interval_hours": 24,
    "report_interval_hours": 6,
    "health_check_interval_minutes": 5,
    "data_retention_days": 90,
    "max_retry_attempts": 3,
    "retry_delay_seconds": 60,
    "enable_notifications": false,
    "notification_webhook": "",
    "provinces_to_crawl": [],
    "priority_varieties": ["白萝卜", "土豆", "白菜", "西红柿", "黄瓜"],
    "performance_monitoring": true
}
EOF
    
    log_info "应用目录结构创建完成: $APP_DIR"
}

# 创建systemd服务
create_systemd_services() {
    log_step "创建systemd服务..."
    
    APP_DIR="$HOME/market-price-system"
    VENV_DIR="$HOME/market-price-env"
    USER=$(whoami)
    
    # API服务
    sudo tee /etc/systemd/system/market-price-api.service > /dev/null << EOF
[Unit]
Description=Market Price API Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$VENV_DIR/bin
ExecStart=$VENV_DIR/bin/python api_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 调度器服务
    sudo tee /etc/systemd/system/market-price-scheduler.service > /dev/null << EOF
[Unit]
Description=Market Price Scheduler Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$VENV_DIR/bin
ExecStart=$VENV_DIR/bin/python scheduler_service.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable market-price-api.service
    sudo systemctl enable market-price-scheduler.service
    
    log_info "systemd服务创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本..."
    
    APP_DIR="$HOME/market-price-system"
    
    # 启动脚本
    cat > "$APP_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "启动农产品市场价格监控系统..."
sudo systemctl start market-price-api.service
sudo systemctl start market-price-scheduler.service
echo "系统已启动"
echo "API服务: http://localhost:8000"
echo "API文档: http://localhost:8000/docs"
EOF

    # 停止脚本
    cat > "$APP_DIR/stop.sh" << 'EOF'
#!/bin/bash
echo "停止农产品市场价格监控系统..."
sudo systemctl stop market-price-api.service
sudo systemctl stop market-price-scheduler.service
echo "系统已停止"
EOF

    # 状态检查脚本
    cat > "$APP_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "=== 农产品市场价格监控系统状态 ==="
echo
echo "API服务状态:"
sudo systemctl status market-price-api.service --no-pager -l
echo
echo "调度器服务状态:"
sudo systemctl status market-price-scheduler.service --no-pager -l
echo
echo "最近日志:"
sudo journalctl -u market-price-api.service -n 10 --no-pager
EOF

    # 日志查看脚本
    cat > "$APP_DIR/logs.sh" << 'EOF'
#!/bin/bash
if [[ "$1" == "api" ]]; then
    sudo journalctl -u market-price-api.service -f
elif [[ "$1" == "scheduler" ]]; then
    sudo journalctl -u market-price-scheduler.service -f
else
    echo "用法: $0 [api|scheduler]"
    echo "查看API日志: $0 api"
    echo "查看调度器日志: $0 scheduler"
fi
EOF

    # 数据备份脚本
    cat > "$APP_DIR/backup.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/market_data_backup_$TIMESTAMP.tar.gz"

echo "创建数据备份..."
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_FILE" data/ logs/ reports/
echo "备份完成: $BACKUP_FILE"
EOF

    # 设置执行权限
    chmod +x "$APP_DIR"/*.sh
    
    log_info "管理脚本创建完成"
}

# 初始化数据库
initialize_database() {
    log_step "初始化数据库..."
    
    APP_DIR="$HOME/market-price-system"
    VENV_DIR="$HOME/market-price-env"
    
    cd "$APP_DIR"
    source "$VENV_DIR/bin/activate"
    
    # 运行数据库初始化
    python -c "
from database_manager import DatabaseManager
db = DatabaseManager('data/market_data.db')
print('数据库初始化完成')
"
    
    log_info "数据库初始化完成"
}

# 测试安装
test_installation() {
    log_step "测试安装..."
    
    APP_DIR="$HOME/market-price-system"
    VENV_DIR="$HOME/market-price-env"
    
    cd "$APP_DIR"
    source "$VENV_DIR/bin/activate"
    
    # 测试导入
    python -c "
import sys
try:
    from market_crawler import MarketCrawler
    from api_server import app
    from database_manager import DatabaseManager
    from location_service import LocationService
    from scheduler_service import SchedulerService
    print('所有模块导入成功')
except ImportError as e:
    print(f'模块导入失败: {e}')
    sys.exit(1)
"
    
    log_info "安装测试通过"
}

# 显示安装完成信息
show_completion_info() {
    log_info "安装完成！"
    echo
    echo "=== 农产品市场价格监控系统 ==="
    echo "安装目录: $HOME/market-price-system"
    echo "虚拟环境: $HOME/market-price-env"
    echo
    echo "管理命令:"
    echo "  启动系统: cd $HOME/market-price-system && ./start.sh"
    echo "  停止系统: cd $HOME/market-price-system && ./stop.sh"
    echo "  查看状态: cd $HOME/market-price-system && ./status.sh"
    echo "  查看日志: cd $HOME/market-price-system && ./logs.sh [api|scheduler]"
    echo "  数据备份: cd $HOME/market-price-system && ./backup.sh"
    echo
    echo "API访问:"
    echo "  API服务: http://localhost:8000"
    echo "  API文档: http://localhost:8000/docs"
    echo "  健康检查: http://localhost:8000/api/health"
    echo
    echo "配置文件:"
    echo "  应用配置: $HOME/market-price-system/config/app_config.json"
    echo "  调度配置: $HOME/market-price-system/scheduler_config.json"
    echo
    echo "现在可以运行 './start.sh' 启动系统"
}

# 主安装流程
main() {
    echo "=== 农产品市场价格监控系统安装程序 ==="
    echo "适用于 ubuntu22.04-py311-torch2.3.1-1.27.0 环境"
    echo
    
    check_root
    check_environment
    install_system_dependencies
    create_virtual_environment
    install_python_dependencies
    create_app_structure
    create_systemd_services
    create_management_scripts
    initialize_database
    test_installation
    show_completion_info
}

# 运行主程序
main "$@"
