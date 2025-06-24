@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 农产品价格监控系统 - 可视化管理面板启动脚本 (Windows)

echo.
echo 🚀 农产品价格监控系统 - 可视化管理面板
echo ==================================
echo.

:: 检查Docker是否安装
echo [STEP] 检查Docker环境...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker未安装，请先安装Docker Desktop
    pause
    exit /b 1
)

:: 检查Docker是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker服务未运行，请启动Docker Desktop
    pause
    exit /b 1
)
echo [INFO] Docker环境检查通过

:: 检查必要文件
echo [STEP] 检查必要文件...
if not exist "docker-compose.yml" (
    echo [ERROR] docker-compose.yml文件不存在
    pause
    exit /b 1
)
if not exist "Dockerfile.dashboard" (
    echo [ERROR] Dockerfile.dashboard文件不存在
    pause
    exit /b 1
)
if not exist "dashboard" (
    echo [ERROR] dashboard目录不存在
    pause
    exit /b 1
)
echo [INFO] 必要文件检查通过

:: 设置Portainer密码
echo [STEP] 设置Portainer密码...
echo admin123456 > portainer_password
echo [INFO] Portainer密码已设置
echo [WARN] 默认用户名: admin
echo [WARN] 默认密码: admin123456

:: 创建必要目录
echo [STEP] 创建必要目录...
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "reports" mkdir reports
if not exist "backups" mkdir backups
if not exist "grafana\provisioning\dashboards" mkdir grafana\provisioning\dashboards
if not exist "grafana\provisioning\datasources" mkdir grafana\provisioning\datasources
echo [INFO] 目录创建完成

:: 启动核心服务
echo [STEP] 启动核心服务...
echo 停止现有服务...
docker-compose down >nul 2>&1

echo 启动核心服务...
docker-compose up -d market-api scheduler portainer dashboard
if errorlevel 1 (
    echo [ERROR] 服务启动失败
    pause
    exit /b 1
)
echo [INFO] 核心服务启动完成

:: 等待服务启动
echo [STEP] 等待服务启动...

echo 等待API服务启动...
set /a count=0
:wait_api
set /a count+=1
if !count! gtr 30 (
    echo [WARN] API服务启动超时
    goto wait_portainer
)
curl -s http://localhost:8000/api/health >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_api
)
echo [INFO] API服务启动成功

:wait_portainer
echo 等待Portainer服务启动...
set /a count=0
:wait_portainer_loop
set /a count+=1
if !count! gtr 30 (
    echo [WARN] Portainer服务启动超时
    goto wait_dashboard
)
curl -s http://localhost:9000 >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_portainer_loop
)
echo [INFO] Portainer服务启动成功

:wait_dashboard
echo 等待Dashboard服务启动...
set /a count=0
:wait_dashboard_loop
set /a count+=1
if !count! gtr 30 (
    echo [WARN] Dashboard服务启动超时
    goto show_info
)
curl -s http://localhost:8080 >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_dashboard_loop
)
echo [INFO] Dashboard服务启动成功

:show_info
echo.
echo 🎉 可视化管理面板启动完成！
echo ==================================
echo.
echo 📊 访问地址:
echo   🏠 管理面板:     http://localhost:8080
echo   📈 数据面板:     http://localhost:8000/static/
echo   📚 API文档:      http://localhost:8000/docs
echo   🐳 Portainer:    http://localhost:9000
echo.
echo 🔐 默认账户信息:
echo   Portainer:    admin / admin123456
echo.
echo 🔧 管理命令:
echo   查看状态:     docker-compose ps
echo   查看日志:     docker-compose logs -f
echo   停止服务:     docker-compose down
echo   重启服务:     docker-compose restart
echo.
echo 📝 功能说明:
echo   • 管理面板: 统一的系统管理界面
echo   • 数据面板: 农产品价格数据展示
echo   • Portainer: Docker容器可视化管理
echo   • API文档: 接口文档和测试
echo.
echo 🚀 下一步:
echo   1. 访问管理面板开始使用
echo   2. 在Portainer中管理Docker容器
echo   3. 查看数据面板了解价格信息
echo.

:: 询问是否打开浏览器
set /p open_browser="是否现在打开管理面板? (y/n): "
if /i "!open_browser!"=="y" (
    start http://localhost:8080
)

pause
