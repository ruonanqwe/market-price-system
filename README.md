# 农产品市场价格监控系统

一个基于Python的农产品市场价格实时监控和API服务系统，支持全国各省市场价格数据爬取、地理位置就近推荐、价格趋势分析等功能。

## 🚀 功能特性

- **实时数据爬取**: 自动爬取全国各省农产品市场价格数据
- **RESTful API**: 提供完整的价格查询API接口
- **地理位置服务**: 根据用户位置推荐就近市场价格
- **价格趋势分析**: 支持历史价格对比和趋势分析
- **定时任务**: 自动化数据更新和清理
- **容器化部署**: 支持Docker一键部署
- **监控告警**: 集成Prometheus和Grafana监控
- **数据导出**: 支持CSV、JSON、Excel格式导出

## 📋 系统要求

### 推荐环境

- **操作系统**: Ubuntu 22.04 LTS
- **Python版本**: 3.11
- **内存**: 32GB
- **CPU**: 8核
- **存储**: 100GB+ SSD

### 预装环境

- ubuntu22.04-py311-torch2.3.1-1.27.0
- ModelScope Library

## 🛠️ 快速开始

### 方式一：Docker部署（推荐）

1. **克隆项目**

```bash
git clone https://github.com/ruonanqwe/market-price-system
cd market-price-system
```

2. **运行Docker安装脚本**

```bash
chmod +x docker-install.sh
./docker-install.sh
```

3. **启动服务**

```bash
cd ~/market-price-docker
./start.sh
```

4. **访问服务**

- API服务: http://localhost:8000
- API文档: http://localhost:8000/docs
- 监控面板: http://localhost:3000

### 方式二：本地部署

1. **运行安装脚本**

```bash
chmod +x install.sh
./install.sh
```

2. **启动服务**

```bash
cd ~/market-price-system
./start.sh
```

## 📚 API文档

### 基础接口

#### 健康检查

```http
GET /api/health
```

#### 获取省份列表

```http
GET /api/provinces
```

#### 获取品种列表

```http
GET /api/varieties?province=广东省
```

#### 获取市场列表

```http
GET /api/markets?province=广东省
```

### 价格查询接口

#### 查询市场价格

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

#### 根据地理位置查询附近价格

```http
POST /api/prices/nearby
Content-Type: application/json

{
    "latitude": 23.1291,
    "longitude": 113.2644,
    "radius": 50
}
```

### 响应格式

```json
{
    "success": true,
    "count": 10,
    "data": [
        {
            "market_name": "广州江南果菜批发市场",
            "variety_name": "白萝卜",
            "avg_price": 2.5,
            "min_price": 2.0,
            "max_price": 3.0,
            "unit": "元/公斤",
            "trade_date": "2024-01-15",
            "province": "广东省"
        }
    ]
}
```

## 🔧 配置说明

### 应用配置 (config/app_config.json)

```json
{
    "app_name": "农产品市场价格监控系统",
    "version": "1.0.0",
    "api_host": "0.0.0.0",
    "api_port": 8000,
    "db_path": "data/market_data.db",
    "log_level": "INFO",
    "data_retention_days": 90
}
```

### 调度器配置 (scheduler_config.json)

```json
{
    "crawl_interval_minutes": 30,
    "cleanup_interval_hours": 24,
    "report_interval_hours": 6,
    "health_check_interval_minutes": 5,
    "data_retention_days": 90,
    "enable_notifications": false,
    "provinces_to_crawl": [],
    "priority_varieties": ["白萝卜", "土豆", "白菜", "西红柿", "黄瓜"]
}
```

## 🗄️ 数据库结构

系统使用SQLite数据库，主要表结构：

### market_prices (市场价格表)

- `market_id`: 市场ID
- `market_name`: 市场名称
- `variety_name`: 品种名称
- `min_price`: 最低价
- `avg_price`: 平均价
- `max_price`: 最高价
- `unit`: 计量单位
- `trade_date`: 交易日期
- `province`: 省份
- `crawl_time`: 爬取时间

### markets (市场信息表)

- `market_id`: 市场ID
- `market_name`: 市场名称
- `province`: 省份
- `latitude`: 纬度
- `longitude`: 经度

### varieties (品种信息表)

- `variety_id`: 品种ID
- `variety_name`: 品种名称
- `variety_type`: 品种类型
- `unit`: 计量单位

## 🔍 监控和日志

### 系统监控

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

### 日志查看

```bash
# 查看API服务日志
./logs.sh api

# 查看调度器日志
./logs.sh scheduler

# Docker环境查看日志
docker-compose logs -f market-api
```

### 健康检查

```bash
# 检查系统状态
./status.sh

# 检查API健康状态
curl http://localhost:8000/api/health
```

## 📊 数据管理

### 数据备份

```bash
# 本地部署备份
./backup.sh

# Docker部署备份
./backup.sh
```

### 数据清理

系统会自动清理90天前的数据，也可以手动清理：

```python
from database_manager import DatabaseManager
db = DatabaseManager()
db.cleanup_old_data(days=30)  # 清理30天前的数据
```

### 数据导出

```python
from database_manager import DatabaseManager
db = DatabaseManager()
db.export_data("export.csv", format="csv", filters={"province": "广东省"})
```

## 🚀 性能优化

### 数据库优化

- 使用WAL模式提高并发性能
- 创建复合索引优化查询
- 定期执行VACUUM清理

### API性能

- 使用连接池管理数据库连接
- 实现查询结果缓存
- 支持分页查询

### 爬虫优化

- 实现断点续传
- 支持并发爬取
- 智能重试机制

## 🔒 安全配置

### API安全

- 实现请求频率限制
- 添加CORS跨域配置
- 使用HTTPS加密传输

### 数据安全

- 定期数据备份
- 数据库访问权限控制
- 敏感信息加密存储

## 🐛 故障排除

### 常见问题

1. **服务启动失败**

```bash
# 检查端口占用
sudo netstat -tlnp | grep :8000

# 检查日志
./logs.sh api
```

2. **数据库连接失败**

```bash
# 检查数据库文件权限
ls -la data/market_data.db

# 重新初始化数据库
python -c "from database_manager import DatabaseManager; DatabaseManager()"
```

3. **爬虫无数据**

```bash
# 检查网络连接
curl -I https://pfsc.agri.cn

# 检查调度器日志
./logs.sh scheduler
```

### 性能问题

1. **API响应慢**

- 检查数据库索引
- 优化查询条件
- 增加缓存

2. **内存占用高**

- 调整爬虫并发数
- 清理历史数据
- 重启服务

## 📈 扩展开发

### 添加新的数据源

1. 继承`MarketCrawler`类
2. 实现数据获取方法
3. 注册到调度器

### 自定义API接口

1. 在`api_server.py`中添加路由
2. 实现业务逻辑
3. 更新API文档

### 集成第三方服务

1. 地图服务API
2. 消息推送服务
3. 数据分析平台

## 🌐 插件使用示例

### Python客户端示例

```python
import requests
import json

class MarketPriceClient:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url

    def get_nearby_prices(self, lat, lon, radius=50):
        """获取附近市场价格"""
        url = f"{self.base_url}/api/prices/nearby"
        data = {
            "latitude": lat,
            "longitude": lon,
            "radius": radius
        }
        response = requests.post(url, json=data)
        return response.json()

    def query_prices(self, **filters):
        """查询价格数据"""
        url = f"{self.base_url}/api/prices/query"
        response = requests.post(url, json=filters)
        return response.json()

# 使用示例
client = MarketPriceClient()

# 获取广州附近50公里的市场价格
nearby = client.get_nearby_prices(23.1291, 113.2644, 50)
print(f"找到 {nearby['count']} 个附近市场")

# 查询广东省白萝卜价格
prices = client.query_prices(
    province="广东省",
    variety_name="白萝卜",
    limit=10
)
print(f"找到 {prices['count']} 条价格记录")
```

### JavaScript客户端示例

```javascript
class MarketPriceAPI {
    constructor(baseURL = 'http://localhost:8000') {
        this.baseURL = baseURL;
    }

    async getNearbyPrices(lat, lon, radius = 50) {
        const response = await fetch(`${this.baseURL}/api/prices/nearby`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                latitude: lat,
                longitude: lon,
                radius: radius
            })
        });
        return await response.json();
    }

    async queryPrices(filters) {
        const response = await fetch(`${this.baseURL}/api/prices/query`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(filters)
        });
        return await response.json();
    }
}

// 使用示例
const api = new MarketPriceAPI();

// 获取用户位置附近的价格
navigator.geolocation.getCurrentPosition(async (position) => {
    const { latitude, longitude } = position.coords;
    const nearby = await api.getNearbyPrices(latitude, longitude, 100);
    console.log('附近市场价格:', nearby);
});
```

### curl命令示例

```bash
# 健康检查
curl -X GET "http://localhost:8000/api/health"

# 获取省份列表
curl -X GET "http://localhost:8000/api/provinces"

# 查询价格数据
curl -X POST "http://localhost:8000/api/prices/query" \
     -H "Content-Type: application/json" \
     -d '{
       "province": "广东省",
       "variety_name": "白萝卜",
       "limit": 10
     }'

# 根据位置查询附近价格
curl -X POST "http://localhost:8000/api/prices/nearby" \
     -H "Content-Type: application/json" \
     -d '{
       "latitude": 23.1291,
       "longitude": 113.2644,
       "radius": 50
     }'
```

## 📞 技术支持

如有问题或建议，请联系：

- 邮箱: support@example.com
- 文档: [在线文档地址]
- 问题反馈: [GitHub Issues]

## 📄 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。
