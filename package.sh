#!/bin/bash

# 农产品市场价格监控系统插件打包脚本
# 将所有文件打包成可部署的插件包

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 配置变量
PLUGIN_NAME="market-price-system"
PLUGIN_VERSION="1.0.0"
PACKAGE_NAME="${PLUGIN_NAME}-v${PLUGIN_VERSION}"
BUILD_DIR="build"
DIST_DIR="dist"

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

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# 显示打包信息
show_package_info() {
    clear
    echo -e "${PURPLE}"
    echo "=================================================================="
    echo "           农产品市场价格监控系统插件打包工具"
    echo "                    v$PLUGIN_VERSION"
    echo "=================================================================="
    echo -e "${NC}"
    echo "📦 打包内容:"
    echo "   • Python应用程序文件"
    echo "   • Docker部署配置"
    echo "   • 系统服务配置"
    echo "   • 数据库管理脚本"
    echo "   • 监控和日志配置"
    echo "   • 一键部署脚本"
    echo "   • 完整文档和示例"
    echo
    echo "🎯 目标环境:"
    echo "   • Ubuntu 22.04 LTS"
    echo "   • Python 3.11"
    echo "   • 8核CPU + 32GB内存"
    echo "   • ModelScope Library"
    echo
}

# 清理构建目录
clean_build_dir() {
    log_step "清理构建目录..."
    
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
    
    if [[ -d "$DIST_DIR" ]]; then
        rm -rf "$DIST_DIR"
    fi
    
    mkdir -p "$BUILD_DIR/$PACKAGE_NAME"
    mkdir -p "$DIST_DIR"
    
    log_info "构建目录已清理"
}

# 复制核心文件
copy_core_files() {
    log_step "复制核心应用文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    # Python应用文件
    cp market_crawler.py "$target_dir/"
    cp api_server.py "$target_dir/"
    cp database_manager.py "$target_dir/"
    cp location_service.py "$target_dir/"
    cp scheduler_service.py "$target_dir/"
    cp requirements.txt "$target_dir/"
    
    log_info "核心文件复制完成"
}

# 复制配置文件
copy_config_files() {
    log_step "复制配置文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    # 创建配置目录
    mkdir -p "$target_dir/config"
    
    # 配置文件
    cp plugin_config.yaml "$target_dir/config/"
    cp .env.example "$target_dir/"
    cp plugin_info.json "$target_dir/"
    
    # Docker配置
    cp Dockerfile "$target_dir/"
    cp docker-compose.yml "$target_dir/"
    cp nginx.conf "$target_dir/"
    
    log_info "配置文件复制完成"
}

# 复制部署脚本
copy_deployment_scripts() {
    log_step "复制部署脚本..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    # 部署脚本
    cp deploy.sh "$target_dir/"
    cp install.sh "$target_dir/"
    cp docker-install.sh "$target_dir/"
    
    # 设置执行权限
    chmod +x "$target_dir"/*.sh
    
    log_info "部署脚本复制完成"
}

# 复制文档文件
copy_documentation() {
    log_step "复制文档文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    # 创建文档目录
    mkdir -p "$target_dir/docs"
    
    # 主要文档
    cp README.md "$target_dir/"
    
    # 创建额外文档
    create_installation_guide "$target_dir"
    create_api_documentation "$target_dir"
    create_troubleshooting_guide "$target_dir"
    
    log_info "文档文件复制完成"
}

# 创建安装指南
create_installation_guide() {
    local target_dir="$1"
    
    cat > "$target_dir/docs/INSTALLATION.md" << 'EOF'
# 安装指南

## 快速安装

### 方式一：一键部署（推荐）
```bash
chmod +x deploy.sh
./deploy.sh
```

### 方式二：Docker部署
```bash
chmod +x docker-install.sh
./docker-install.sh
```

### 方式三：本地部署
```bash
chmod +x install.sh
./install.sh
```

## 系统要求

- Ubuntu 22.04 LTS
- Python 3.11
- 8核CPU + 32GB内存
- 10GB+ 存储空间
- 互联网连接

## 端口说明

- 8000: API服务端口
- 80: Nginx代理端口
- 3000: Grafana监控面板
- 9090: Prometheus监控

## 配置文件

- `config/plugin_config.yaml`: 主配置文件
- `.env`: 环境变量配置
- `scheduler_config.json`: 调度器配置

## 服务管理

### Docker部署
```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 本地部署
```bash
# 启动服务
sudo systemctl start market-price-api.service

# 停止服务
sudo systemctl stop market-price-api.service

# 查看状态
sudo systemctl status market-price-api.service

# 查看日志
sudo journalctl -u market-price-api.service -f
```
EOF
}

# 创建API文档
create_api_documentation() {
    local target_dir="$1"
    
    cat > "$target_dir/docs/API.md" << 'EOF'
# API文档

## 基础信息

- 基础URL: `http://localhost:8000`
- 内容类型: `application/json`
- 认证方式: 无需认证（可配置API密钥）

## 接口列表

### 1. 健康检查
```http
GET /api/health
```

**响应示例:**
```json
{
    "status": "healthy",
    "timestamp": "2024-12-05T10:00:00Z",
    "crawler_running": true
}
```

### 2. 获取省份列表
```http
GET /api/provinces
```

### 3. 查询价格数据
```http
POST /api/prices/query
Content-Type: application/json

{
    "province": "广东省",
    "variety_name": "白萝卜",
    "start_date": "2024-01-01",
    "end_date": "2024-01-31",
    "limit": 100
}
```

### 4. 地理位置查询
```http
POST /api/prices/nearby
Content-Type: application/json

{
    "latitude": 23.1291,
    "longitude": 113.2644,
    "radius": 50
}
```

## 错误码说明

- 200: 成功
- 400: 请求参数错误
- 404: 资源不存在
- 500: 服务器内部错误

## 使用示例

### Python示例
```python
import requests

# 查询价格数据
response = requests.post('http://localhost:8000/api/prices/query', 
    json={'province': '广东省', 'variety_name': '白萝卜'})
data = response.json()
print(f"找到 {data['count']} 条记录")
```

### JavaScript示例
```javascript
// 获取附近价格
fetch('http://localhost:8000/api/prices/nearby', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
        latitude: 23.1291,
        longitude: 113.2644,
        radius: 50
    })
})
.then(response => response.json())
.then(data => console.log(data));
```
EOF
}

# 创建故障排除指南
create_troubleshooting_guide() {
    local target_dir="$1"
    
    cat > "$target_dir/docs/TROUBLESHOOTING.md" << 'EOF'
# 故障排除指南

## 常见问题

### 1. 服务启动失败

**问题**: 服务无法启动
**解决方案**:
```bash
# 检查端口占用
sudo netstat -tlnp | grep :8000

# 检查日志
sudo journalctl -u market-price-api.service -n 50

# 重启服务
sudo systemctl restart market-price-api.service
```

### 2. 数据库连接失败

**问题**: 无法连接到数据库
**解决方案**:
```bash
# 检查数据库文件
ls -la data/market_data.db

# 重新初始化数据库
python -c "from database_manager import DatabaseManager; DatabaseManager()"
```

### 3. 爬虫无数据

**问题**: 爬虫运行但没有获取到数据
**解决方案**:
```bash
# 检查网络连接
curl -I https://pfsc.agri.cn

# 检查爬虫日志
tail -f logs/crawler.log

# 手动运行爬虫测试
python market_crawler.py --mode=api
```

### 4. API响应慢

**问题**: API接口响应时间过长
**解决方案**:
- 检查数据库索引
- 优化查询条件
- 增加缓存配置
- 清理历史数据

### 5. 内存占用过高

**问题**: 系统内存使用率过高
**解决方案**:
- 调整爬虫并发数
- 清理历史数据
- 重启服务
- 检查内存泄漏

## 日志文件位置

- API服务日志: `logs/api.log`
- 调度器日志: `logs/scheduler.log`
- 爬虫日志: `logs/crawler.log`
- 错误日志: `logs/error.log`

## 性能优化建议

1. **数据库优化**
   - 定期执行VACUUM
   - 创建合适的索引
   - 清理过期数据

2. **系统优化**
   - 调整系统参数
   - 优化磁盘I/O
   - 监控系统资源

3. **应用优化**
   - 启用缓存
   - 优化查询逻辑
   - 使用连接池

## 联系支持

如果问题仍然存在，请联系技术支持：
- 邮箱: support@example.com
- 提供错误日志和系统信息
EOF
}

# 创建示例文件
create_examples() {
    log_step "创建示例文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    mkdir -p "$target_dir/examples"
    
    # Python客户端示例
    cat > "$target_dir/examples/python_client.py" << 'EOF'
#!/usr/bin/env python3
"""
农产品市场价格API Python客户端示例
"""

import requests
import json
from typing import Dict, List, Optional

class MarketPriceClient:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def health_check(self) -> Dict:
        """健康检查"""
        response = self.session.get(f"{self.base_url}/api/health")
        return response.json()
    
    def get_provinces(self) -> List[Dict]:
        """获取省份列表"""
        response = self.session.get(f"{self.base_url}/api/provinces")
        return response.json()
    
    def get_varieties(self, province: Optional[str] = None) -> List[str]:
        """获取品种列表"""
        params = {"province": province} if province else {}
        response = self.session.get(f"{self.base_url}/api/varieties", params=params)
        return response.json()
    
    def query_prices(self, **filters) -> Dict:
        """查询价格数据"""
        response = self.session.post(f"{self.base_url}/api/prices/query", json=filters)
        return response.json()
    
    def get_nearby_prices(self, lat: float, lon: float, radius: int = 50) -> Dict:
        """获取附近市场价格"""
        data = {"latitude": lat, "longitude": lon, "radius": radius}
        response = self.session.post(f"{self.base_url}/api/prices/nearby", json=data)
        return response.json()

def main():
    # 创建客户端
    client = MarketPriceClient()
    
    # 健康检查
    health = client.health_check()
    print(f"服务状态: {health['status']}")
    
    # 获取省份列表
    provinces = client.get_provinces()
    print(f"支持省份数量: {len(provinces['data'])}")
    
    # 查询广东省白萝卜价格
    prices = client.query_prices(
        province="广东省",
        variety_name="白萝卜",
        limit=10
    )
    print(f"找到价格记录: {prices['count']} 条")
    
    # 获取广州附近的市场价格
    nearby = client.get_nearby_prices(23.1291, 113.2644, 100)
    print(f"附近市场数量: {nearby['count']}")

if __name__ == "__main__":
    main()
EOF

    # JavaScript客户端示例
    cat > "$target_dir/examples/javascript_client.js" << 'EOF'
/**
 * 农产品市场价格API JavaScript客户端示例
 */

class MarketPriceAPI {
    constructor(baseURL = 'http://localhost:8000') {
        this.baseURL = baseURL;
    }
    
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        return await response.json();
    }
    
    async healthCheck() {
        return await this.request('/api/health');
    }
    
    async getProvinces() {
        return await this.request('/api/provinces');
    }
    
    async getVarieties(province = null) {
        const params = province ? `?province=${encodeURIComponent(province)}` : '';
        return await this.request(`/api/varieties${params}`);
    }
    
    async queryPrices(filters) {
        return await this.request('/api/prices/query', {
            method: 'POST',
            body: JSON.stringify(filters)
        });
    }
    
    async getNearbyPrices(lat, lon, radius = 50) {
        return await this.request('/api/prices/nearby', {
            method: 'POST',
            body: JSON.stringify({
                latitude: lat,
                longitude: lon,
                radius: radius
            })
        });
    }
}

// 使用示例
async function main() {
    const api = new MarketPriceAPI();
    
    try {
        // 健康检查
        const health = await api.healthCheck();
        console.log('服务状态:', health.status);
        
        // 获取省份列表
        const provinces = await api.getProvinces();
        console.log('支持省份数量:', provinces.data.length);
        
        // 查询价格数据
        const prices = await api.queryPrices({
            province: '广东省',
            variety_name: '白萝卜',
            limit: 10
        });
        console.log('找到价格记录:', prices.count, '条');
        
        // 获取用户位置附近的价格（需要用户授权）
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(async (position) => {
                const { latitude, longitude } = position.coords;
                const nearby = await api.getNearbyPrices(latitude, longitude, 100);
                console.log('附近市场数量:', nearby.count);
            });
        }
        
    } catch (error) {
        console.error('API调用失败:', error);
    }
}

// 在浏览器环境中运行
if (typeof window !== 'undefined') {
    main();
}

// 在Node.js环境中导出
if (typeof module !== 'undefined' && module.exports) {
    module.exports = MarketPriceAPI;
}
EOF

    log_info "示例文件创建完成"
}

# 创建版本信息文件
create_version_file() {
    log_step "创建版本信息文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    cat > "$target_dir/VERSION" << EOF
农产品市场价格监控系统
版本: $PLUGIN_VERSION
构建时间: $(date '+%Y-%m-%d %H:%M:%S')
构建环境: $(uname -a)
Git提交: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

系统要求:
- Ubuntu 22.04 LTS
- Python 3.11
- 8核CPU + 32GB内存
- ModelScope Library

功能特性:
- 实时数据爬取
- RESTful API接口
- 地理位置服务
- 价格趋势分析
- Docker容器化部署
- 监控和告警

作者: xiaohai
许可证: MIT
EOF

    log_info "版本信息文件创建完成"
}

# 创建许可证文件
create_license_file() {
    log_step "创建许可证文件..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    cat > "$target_dir/LICENSE" << 'EOF'
MIT License

Copyright (c) 2024 农产品市场价格监控系统

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    log_info "许可证文件创建完成"
}

# 创建目录结构
create_directory_structure() {
    log_step "创建目录结构..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    
    # 创建必要的目录
    mkdir -p "$target_dir"/{data,logs,reports,backups,ssl,grafana/provisioning}
    
    # 创建空的.gitkeep文件
    touch "$target_dir/data/.gitkeep"
    touch "$target_dir/logs/.gitkeep"
    touch "$target_dir/reports/.gitkeep"
    touch "$target_dir/backups/.gitkeep"
    
    log_info "目录结构创建完成"
}

# 验证打包内容
verify_package() {
    log_step "验证打包内容..."
    
    local target_dir="$BUILD_DIR/$PACKAGE_NAME"
    local required_files=(
        "market_crawler.py"
        "api_server.py"
        "database_manager.py"
        "location_service.py"
        "scheduler_service.py"
        "requirements.txt"
        "deploy.sh"
        "README.md"
        "plugin_info.json"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$target_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "缺少必要文件: ${missing_files[*]}"
        exit 1
    fi
    
    log_success "打包内容验证通过"
}

# 创建压缩包
create_archive() {
    log_step "创建压缩包..."
    
    cd "$BUILD_DIR"
    
    # 创建tar.gz压缩包
    tar -czf "../$DIST_DIR/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
    
    # 创建zip压缩包
    zip -r "../$DIST_DIR/${PACKAGE_NAME}.zip" "$PACKAGE_NAME" > /dev/null
    
    cd ..
    
    # 计算文件大小和校验和
    local tar_size=$(du -h "$DIST_DIR/${PACKAGE_NAME}.tar.gz" | cut -f1)
    local zip_size=$(du -h "$DIST_DIR/${PACKAGE_NAME}.zip" | cut -f1)
    local tar_md5=$(md5sum "$DIST_DIR/${PACKAGE_NAME}.tar.gz" | cut -d' ' -f1)
    local zip_md5=$(md5sum "$DIST_DIR/${PACKAGE_NAME}.zip" | cut -d' ' -f1)
    
    # 创建校验和文件
    cat > "$DIST_DIR/checksums.txt" << EOF
# 农产品市场价格监控系统 v$PLUGIN_VERSION 校验和
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

${PACKAGE_NAME}.tar.gz  $tar_md5  $tar_size
${PACKAGE_NAME}.zip     $zip_md5  $zip_size
EOF
    
    log_success "压缩包创建完成"
    log_info "tar.gz: $tar_size (MD5: $tar_md5)"
    log_info "zip: $zip_size (MD5: $zip_md5)"
}

# 显示完成信息
show_completion_info() {
    echo
    log_success "🎉 插件打包完成！"
    echo
    echo -e "${PURPLE}=== 打包结果 ===${NC}"
    echo "📦 压缩包位置: $DIST_DIR/"
    echo "   • ${PACKAGE_NAME}.tar.gz"
    echo "   • ${PACKAGE_NAME}.zip"
    echo "   • checksums.txt"
    echo
    echo -e "${PURPLE}=== 部署说明 ===${NC}"
    echo "1. 上传压缩包到目标服务器"
    echo "2. 解压缩包: tar -xzf ${PACKAGE_NAME}.tar.gz"
    echo "3. 进入目录: cd $PACKAGE_NAME"
    echo "4. 运行部署: chmod +x deploy.sh && ./deploy.sh"
    echo
    echo -e "${PURPLE}=== 文件清单 ===${NC}"
    echo "核心文件:"
    echo "  • Python应用程序 (*.py)"
    echo "  • 依赖配置 (requirements.txt)"
    echo "  • Docker配置 (Dockerfile, docker-compose.yml)"
    echo
    echo "部署脚本:"
    echo "  • deploy.sh - 一键部署脚本"
    echo "  • install.sh - 本地安装脚本"
    echo "  • docker-install.sh - Docker安装脚本"
    echo
    echo "配置文件:"
    echo "  • plugin_config.yaml - 主配置文件"
    echo "  • .env.example - 环境变量模板"
    echo "  • plugin_info.json - 插件信息"
    echo
    echo "文档文件:"
    echo "  • README.md - 主要文档"
    echo "  • docs/ - 详细文档目录"
    echo "  • examples/ - 使用示例"
    echo
    echo -e "${GREEN}打包目录: $BUILD_DIR/$PACKAGE_NAME${NC}"
    echo -e "${GREEN}分发目录: $DIST_DIR/${NC}"
}

# 主函数
main() {
    show_package_info
    
    read -p "按回车键开始打包..." -r
    
    clean_build_dir
    copy_core_files
    copy_config_files
    copy_deployment_scripts
    copy_documentation
    create_examples
    create_version_file
    create_license_file
    create_directory_structure
    verify_package
    create_archive
    show_completion_info
}

# 运行主程序
main "$@"
