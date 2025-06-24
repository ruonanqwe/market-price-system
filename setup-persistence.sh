#!/bin/bash

# 农产品价格监控系统 - 持久化配置脚本
# 配置系统服务，确保重启后自动启动

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取当前目录
CURRENT_DIR=$(pwd)
PROJECT_NAME="market-price-system"

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "需要root权限来配置系统服务"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 创建系统用户
create_system_user() {
    log_step "创建系统用户..."
    
    if ! id "marketprice" &>/dev/null; then
        useradd -r -s /bin/false -d /opt/market-price-system marketprice
        log_info "已创建系统用户: marketprice"
    else
        log_info "系统用户已存在: marketprice"
    fi
    
    # 设置目录权限
    chown -R marketprice:marketprice "$CURRENT_DIR"
    log_info "已设置目录权限"
}

# 配置Systemd服务
setup_systemd() {
    log_step "配置Systemd服务..."
    
    # API服务配置
    cat > /etc/systemd/system/market-price-api.service << EOF
[Unit]
Description=Market Price API Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=marketprice
Group=marketprice
WorkingDirectory=$CURRENT_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 $CURRENT_DIR/api_server.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=append:$CURRENT_DIR/api_server.log
StandardError=append:$CURRENT_DIR/api_server.log

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$CURRENT_DIR
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

    # 调度器服务配置
    cat > /etc/systemd/system/market-price-scheduler.service << EOF
[Unit]
Description=Market Price Scheduler Service
After=network.target market-price-api.service
Wants=network.target
Requires=market-price-api.service

[Service]
Type=simple
User=marketprice
Group=marketprice
WorkingDirectory=$CURRENT_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 $CURRENT_DIR/scheduler_service.py
Restart=always
RestartSec=15
StandardOutput=append:$CURRENT_DIR/scheduler_service.log
StandardError=append:$CURRENT_DIR/scheduler_service.log

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$CURRENT_DIR
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable market-price-api.service
    systemctl enable market-price-scheduler.service
    
    log_info "Systemd服务配置完成"
}

# 配置日志轮转
setup_logrotate() {
    log_step "配置日志轮转..."
    
    cat > /etc/logrotate.d/market-price << EOF
$CURRENT_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    su marketprice marketprice
}
EOF
    
    log_info "日志轮转配置完成"
}

# 配置防火墙
setup_firewall() {
    log_step "配置防火墙..."
    
    # UFW配置
    if command -v ufw &> /dev/null; then
        ufw allow 8000/tcp comment "Market Price API"
        log_info "UFW防火墙规则已添加"
    fi
    
    # firewalld配置
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8000/tcp
        firewall-cmd --reload
        log_info "firewalld防火墙规则已添加"
    fi
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本..."
    
    # 启动脚本
    cat > "$CURRENT_DIR/start-services.sh" << 'EOF'
#!/bin/bash
echo "🚀 启动农产品价格监控服务..."
sudo systemctl start market-price-api
sudo systemctl start market-price-scheduler
echo "✅ 服务启动完成"
sudo systemctl status market-price-api --no-pager -l
sudo systemctl status market-price-scheduler --no-pager -l
EOF

    # 停止脚本
    cat > "$CURRENT_DIR/stop-services.sh" << 'EOF'
#!/bin/bash
echo "🛑 停止农产品价格监控服务..."
sudo systemctl stop market-price-scheduler
sudo systemctl stop market-price-api
echo "✅ 服务停止完成"
EOF

    # 重启脚本
    cat > "$CURRENT_DIR/restart-services.sh" << 'EOF'
#!/bin/bash
echo "🔄 重启农产品价格监控服务..."
sudo systemctl restart market-price-api
sudo systemctl restart market-price-scheduler
echo "✅ 服务重启完成"
sudo systemctl status market-price-api --no-pager -l
sudo systemctl status market-price-scheduler --no-pager -l
EOF

    # 状态检查脚本
    cat > "$CURRENT_DIR/service-status.sh" << 'EOF'
#!/bin/bash
echo "📊 农产品价格监控服务状态"
echo "=================================="
echo
echo "🔍 Systemd服务状态:"
sudo systemctl status market-price-api --no-pager -l
echo
sudo systemctl status market-price-scheduler --no-pager -l
echo
echo "🔌 端口监听状态:"
sudo netstat -tlnp | grep :8000
echo
echo "💚 API健康检查:"
curl -s http://localhost:8000/api/health | python3 -m json.tool 2>/dev/null || echo "API无响应"
echo
echo "📝 最近日志:"
echo "--- API日志 ---"
tail -5 api_server.log 2>/dev/null || echo "无API日志"
echo "--- 调度器日志 ---"
tail -5 scheduler_service.log 2>/dev/null || echo "无调度器日志"
EOF

    # 设置执行权限
    chmod +x "$CURRENT_DIR/start-services.sh"
    chmod +x "$CURRENT_DIR/stop-services.sh"
    chmod +x "$CURRENT_DIR/restart-services.sh"
    chmod +x "$CURRENT_DIR/service-status.sh"
    
    log_info "管理脚本创建完成"
}

# 配置开机自启动
setup_autostart() {
    log_step "配置开机自启动..."
    
    # 停止当前手动启动的进程
    pkill -f "python.*api_server" || true
    pkill -f "python.*scheduler_service" || true
    sleep 2
    
    # 启动systemd服务
    systemctl start market-price-api
    systemctl start market-price-scheduler
    
    log_info "服务已启动并配置为开机自启动"
}

# 创建监控脚本
create_monitoring() {
    log_step "创建监控脚本..."
    
    cat > "$CURRENT_DIR/monitor-services.sh" << 'EOF'
#!/bin/bash

# 服务监控脚本 - 检查服务状态并自动重启

LOG_FILE="/var/log/market-price-monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

check_and_restart() {
    local service_name=$1
    
    if ! systemctl is-active --quiet "$service_name"; then
        log_message "WARNING: $service_name is not running, attempting to restart..."
        sudo systemctl restart "$service_name"
        
        sleep 5
        
        if systemctl is-active --quiet "$service_name"; then
            log_message "SUCCESS: $service_name restarted successfully"
        else
            log_message "ERROR: Failed to restart $service_name"
        fi
    else
        log_message "INFO: $service_name is running normally"
    fi
}

# 检查API服务
check_and_restart "market-price-api"

# 检查调度器服务
check_and_restart "market-price-scheduler"

# 检查API响应
if ! curl -s -f http://localhost:8000/api/health > /dev/null; then
    log_message "WARNING: API health check failed, restarting API service..."
    sudo systemctl restart market-price-api
fi
EOF

    chmod +x "$CURRENT_DIR/monitor-services.sh"
    
    # 添加到crontab（每5分钟检查一次）
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CURRENT_DIR/monitor-services.sh") | crontab -
    
    log_info "监控脚本创建完成，已添加到crontab"
}

# 显示配置结果
show_configuration_result() {
    echo
    echo "🎉 持久化配置完成！"
    echo "=================================="
    echo
    echo "📋 已配置的服务:"
    echo "  ✅ market-price-api.service (API服务)"
    echo "  ✅ market-price-scheduler.service (调度器服务)"
    echo
    echo "🔧 管理命令:"
    echo "  启动服务: ./start-services.sh"
    echo "  停止服务: ./stop-services.sh"
    echo "  重启服务: ./restart-services.sh"
    echo "  查看状态: ./service-status.sh"
    echo "  监控服务: ./monitor-services.sh"
    echo
    echo "📊 系统命令:"
    echo "  查看服务状态: sudo systemctl status market-price-api"
    echo "  查看日志: sudo journalctl -u market-price-api -f"
    echo "  启用开机自启: sudo systemctl enable market-price-api"
    echo
    echo "🔍 验证配置:"
    echo "  检查服务: sudo systemctl list-unit-files | grep market-price"
    echo "  测试API: curl http://localhost:8000/api/health"
    echo "  查看端口: sudo netstat -tlnp | grep :8000"
    echo
    echo "📝 日志位置:"
    echo "  API日志: $CURRENT_DIR/api_server.log"
    echo "  调度器日志: $CURRENT_DIR/scheduler_service.log"
    echo "  系统日志: sudo journalctl -u market-price-api"
    echo "  监控日志: /var/log/market-price-monitor.log"
    echo
    echo "🔄 自动监控:"
    echo "  ✅ 每5分钟自动检查服务状态"
    echo "  ✅ 服务异常时自动重启"
    echo "  ✅ 日志自动轮转（保留30天）"
    echo
}

# 主函数
main() {
    echo "🔧 农产品价格监控系统 - 持久化配置"
    echo "=================================="
    echo
    
    check_root
    create_system_user
    setup_systemd
    setup_logrotate
    setup_firewall
    create_management_scripts
    setup_autostart
    create_monitoring
    show_configuration_result
    
    echo "🎯 下一步:"
    echo "1. 运行 ./service-status.sh 检查服务状态"
    echo "2. 运行 ./check-deployment.sh 验证部署"
    echo "3. 重启服务器测试开机自启动"
}

# 运行主函数
main
