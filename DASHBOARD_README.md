# 农产品价格监控系统 - 可视化管理面板

## 概述

这是一个基于 Docker 和 Portainer 的可视化管理面板，为农产品价格监控系统提供统一的管理界面。

## 功能特性

### 🏠 管理面板 (端口 8080)
- **统一管理界面**: 集成所有系统组件的访问入口
- **实时状态监控**: 显示API服务、调度器、数据库等状态
- **快速访问**: 一键跳转到各个子系统
- **系统信息**: 显示运行时间、版本信息等

### 🐳 Portainer (端口 9000)
- **容器管理**: 可视化管理Docker容器
- **镜像管理**: 查看、删除、构建Docker镜像
- **网络管理**: 管理Docker网络配置
- **卷管理**: 管理数据卷和存储
- **日志查看**: 实时查看容器日志
- **资源监控**: 监控CPU、内存使用情况

### 📈 数据面板 (端口 8000/static/)
- **价格数据展示**: 农产品价格数据可视化
- **图表分析**: 价格趋势图表
- **数据筛选**: 按省份、品种、市场筛选
- **实时更新**: 自动刷新最新数据

### 📚 API文档 (端口 8000/docs)
- **接口文档**: 完整的API接口说明
- **在线测试**: 直接在浏览器中测试API
- **参数说明**: 详细的请求参数和响应格式

## 快速开始

### 方式一：Windows 批处理文件
```bash
# 双击运行或在命令行执行
start-dashboard.bat
```

### 方式二：PowerShell 脚本 (Windows)
```powershell
# 在PowerShell中执行
.\start-dashboard.ps1
```

### 方式三：Shell脚本 (Linux/Mac)
```bash
# 添加执行权限
chmod +x start-dashboard.sh

# 运行脚本
./start-dashboard.sh
```

### 方式四：手动启动
```bash
# 1. 设置Portainer密码
echo "admin123456" > portainer_password

# 2. 创建必要目录
mkdir -p data logs reports backups
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources

# 3. 启动服务
docker-compose up -d market-api scheduler portainer dashboard
```

## 访问地址

启动成功后，可以通过以下地址访问各个组件：

| 组件 | 地址 | 说明 |
|------|------|------|
| 管理面板 | http://localhost:8080 | 主要管理界面 |
| 数据面板 | http://localhost:8000/static/ | 价格数据展示 |
| API文档 | http://localhost:8000/docs | 接口文档 |
| Portainer | http://localhost:9000 | Docker管理 |

## 默认账户

| 服务 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| Portainer | admin | admin123456 | 首次登录后请修改 |

## 目录结构

```
├── dashboard/                 # 管理面板前端文件
│   ├── index.html            # 主页面
│   ├── css/                  # 样式文件
│   ├── js/                   # JavaScript文件
│   ├── 404.html              # 404错误页面
│   └── 50x.html              # 服务器错误页面
├── docker-compose.yml        # Docker编排文件
├── Dockerfile.dashboard      # Dashboard镜像构建文件
├── nginx-dashboard.conf      # Nginx配置文件
├── start-dashboard.sh        # Linux/Mac启动脚本
├── start-dashboard.bat       # Windows启动脚本
└── DASHBOARD_README.md       # 本文档
```

## 管理命令

### 查看服务状态
```bash
docker-compose ps
```

### 查看服务日志
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f market-api
docker-compose logs -f portainer
docker-compose logs -f dashboard
```

### 重启服务
```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart market-api
```

### 停止服务
```bash
docker-compose down
```

### 更新服务
```bash
# 重新构建并启动
docker-compose up -d --build
```

## 故障排除

### 1. 端口冲突
如果遇到端口冲突，可以修改 `docker-compose.yml` 中的端口映射：
```yaml
ports:
  - "8081:8080"  # 将8080改为8081
```

### 2. 服务启动失败
检查Docker是否正常运行：
```bash
docker info
```

查看具体错误信息：
```bash
docker-compose logs
```

### 3. 无法访问服务
检查防火墙设置，确保相关端口已开放：
- 8080 (管理面板)
- 8000 (API服务)
- 9000 (Portainer)

### 4. Portainer无法连接Docker
确保Docker socket已正确挂载：
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

## 安全建议

1. **修改默认密码**: 首次登录Portainer后立即修改默认密码
2. **网络安全**: 在生产环境中，建议配置防火墙限制访问
3. **SSL证书**: 生产环境建议配置HTTPS
4. **定期备份**: 定期备份重要数据和配置文件

## 自定义配置

### 修改管理面板样式
编辑 `dashboard/css/dashboard.css` 文件来自定义样式。

### 添加新功能
在 `dashboard/js/dashboard.js` 中添加新的JavaScript功能。

### 修改Nginx配置
编辑 `nginx-dashboard.conf` 来调整反向代理设置。

## 技术栈

- **前端**: HTML5, CSS3, JavaScript, Bootstrap 5
- **后端**: FastAPI, Python
- **容器化**: Docker, Docker Compose
- **反向代理**: Nginx
- **容器管理**: Portainer
- **监控**: Prometheus, Grafana (可选)

## 支持

如果遇到问题，请检查：
1. Docker和Docker Compose版本
2. 系统资源使用情况
3. 网络连接状态
4. 日志文件中的错误信息

## 更新日志

### v1.0.0
- 初始版本发布
- 集成Portainer Docker管理
- 统一管理面板界面
- 基础监控功能
