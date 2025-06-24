#!/bin/bash

# 农产品价格监控系统 - Portainer配置脚本
# 配置Portainer Docker管理界面

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
PORTAINER_PASSWORD="admin123456"  # 默认密码，建议修改

# 检查Docker是否安装
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi
    
    log_info "Docker环境检查通过"
}

# 检查Docker Compose是否安装
check_docker_compose() {
    log_step "检查Docker Compose..."
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    log_info "Docker Compose检查通过"
}

# 生成Portainer密码文件
generate_portainer_password() {
    log_step "生成Portainer管理员密码..."
    
    # 创建密码哈希
    HASHED_PASSWORD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$PORTAINER_PASSWORD" | cut -d ":" -f 2)
    
    # 创建密码文件
    echo "$HASHED_PASSWORD" > portainer_password
    
    log_info "Portainer密码文件已生成"
    log_warn "默认管理员账户: admin"
    log_warn "默认密码: $PORTAINER_PASSWORD"
    log_warn "请在首次登录后修改密码！"
}

# 创建必要的目录
create_directories() {
    log_step "创建必要的目录..."
    
    mkdir -p data logs reports backups
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/provisioning/datasources
    
    log_info "目录创建完成"
}

# 创建Prometheus配置
create_prometheus_config() {
    log_step "创建Prometheus配置..."
    
    cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'market-api'
    static_configs:
      - targets: ['market-api:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
    
    log_info "Prometheus配置文件已创建"
}

# 创建Grafana数据源配置
create_grafana_datasource() {
    log_step "创建Grafana数据源配置..."
    
    cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
    
    log_info "Grafana数据源配置已创建"
}

# 创建Grafana仪表板配置
create_grafana_dashboard() {
    log_step "创建Grafana仪表板配置..."
    
    cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
    
    log_info "Grafana仪表板配置已创建"
}

# 启动服务
start_services() {
    log_step "启动Docker服务..."
    
    # 停止现有服务
    docker-compose down 2>/dev/null || true
    
    # 构建并启动服务
    docker-compose up -d --build
    
    log_info "Docker服务启动完成"
}

# 等待服务启动
wait_for_services() {
    log_step "等待服务启动..."
    
    # 等待API服务
    echo -n "等待API服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:8000/api/health > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # 等待Portainer服务
    echo -n "等待Portainer服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:9000 > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # 等待Dashboard服务
    echo -n "等待Dashboard服务启动"
    for i in {1..30}; do
        if curl -s http://localhost:8080 > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    log_info "所有服务启动完成"
}

# 显示访问信息
show_access_info() {
    echo
    echo "🎉 农产品价格监控系统部署完成！"
    echo "=================================="
    echo
    echo "📊 访问地址:"
    echo "  管理面板:     http://localhost:8080"
    echo "  数据面板:     http://localhost:8000/static/"
    echo "  API文档:      http://localhost:8000/docs"
    echo "  Portainer:    http://localhost:9000"
    echo "  Grafana:      http://localhost:3000"
    echo "  Prometheus:   http://localhost:9090"
    echo
    echo "🔐 默认账户信息:"
    echo "  Portainer:    admin / $PORTAINER_PASSWORD"
    echo "  Grafana:      admin / admin123"
    echo
    echo "🐳 Docker管理命令:"
    echo "  查看状态:     docker-compose ps"
    echo "  查看日志:     docker-compose logs -f"
    echo "  停止服务:     docker-compose down"
    echo "  重启服务:     docker-compose restart"
    echo
    echo "📝 重要提示:"
    echo "  1. 请及时修改默认密码"
    echo "  2. 建议配置SSL证书"
    echo "  3. 定期备份数据"
    echo
}

# 主函数
main() {
    echo "🔧 农产品价格监控系统 - Portainer配置"
    echo "=================================="
    echo
    
    check_docker
    check_docker_compose
    generate_portainer_password
    create_directories
    create_prometheus_config
    create_grafana_datasource
    create_grafana_dashboard
    start_services
    wait_for_services
    show_access_info
    
    echo "🎯 下一步:"
    echo "1. 访问 http://localhost:8080 查看管理面板"
    echo "2. 访问 http://localhost:9000 配置Portainer"
    echo "3. 访问 http://localhost:3000 配置Grafana监控"
}

# 运行主函数
main
