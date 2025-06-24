# 农产品价格监控系统 - 可视化管理面板启动脚本 (PowerShell)

# 设置控制台编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Log-Info($message) {
    Write-ColorOutput Green "[INFO] $message"
}

function Log-Step($message) {
    Write-ColorOutput Cyan "[STEP] $message"
}

function Log-Warn($message) {
    Write-ColorOutput Yellow "[WARN] $message"
}

function Log-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

# 主函数
function Main {
    Write-Host ""
    Write-ColorOutput Cyan "🚀 农产品价格监控系统 - 可视化管理面板"
    Write-ColorOutput Cyan "=================================="
    Write-Host ""

    # 检查Docker环境
    Log-Step "检查Docker环境..."
    try {
        $dockerVersion = docker --version 2>$null
        if (-not $dockerVersion) {
            throw "Docker未安装"
        }
        
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker服务未运行"
        }
        
        Log-Info "Docker环境检查通过"
    }
    catch {
        Log-Error "Docker检查失败: $_"
        Log-Error "请确保Docker Desktop已安装并正在运行"
        Read-Host "按任意键退出"
        exit 1
    }

    # 检查必要文件
    Log-Step "检查必要文件..."
    $requiredFiles = @("docker-compose.yml", "Dockerfile.dashboard")
    $requiredDirs = @("dashboard")
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Log-Error "$file 文件不存在"
            Read-Host "按任意键退出"
            exit 1
        }
    }
    
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir -PathType Container)) {
            Log-Error "$dir 目录不存在"
            Read-Host "按任意键退出"
            exit 1
        }
    }
    
    Log-Info "必要文件检查通过"

    # 设置Portainer密码
    Log-Step "设置Portainer密码..."
    $portainerPassword = "admin123456"
    Set-Content -Path "portainer_password" -Value $portainerPassword -Encoding UTF8
    Log-Info "Portainer密码已设置"
    Log-Warn "默认用户名: admin"
    Log-Warn "默认密码: $portainerPassword"

    # 创建必要目录
    Log-Step "创建必要目录..."
    $directories = @(
        "data", "logs", "reports", "backups",
        "grafana\provisioning\dashboards",
        "grafana\provisioning\datasources"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Log-Info "目录创建完成"

    # 启动核心服务
    Log-Step "启动核心服务..."
    
    # 停止现有服务
    Write-Host "停止现有服务..."
    docker-compose down 2>$null | Out-Null
    
    # 启动核心服务
    Write-Host "启动核心服务..."
    $result = docker-compose up -d market-api scheduler portainer dashboard 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log-Error "服务启动失败"
        Write-Host $result
        Read-Host "按任意键退出"
        exit 1
    }
    Log-Info "核心服务启动完成"

    # 等待服务启动
    Log-Step "等待服务启动..."
    
    # 等待API服务
    Write-Host "等待API服务启动..." -NoNewline
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8000/api/health" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host " ✓" -ForegroundColor Green
                break
            }
        }
        catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
        }
        if ($i -eq 30) {
            Write-Host " ⚠" -ForegroundColor Yellow
            Log-Warn "API服务启动超时"
        }
    }

    # 等待Portainer服务
    Write-Host "等待Portainer服务启动..." -NoNewline
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9000" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host " ✓" -ForegroundColor Green
                break
            }
        }
        catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
        }
        if ($i -eq 30) {
            Write-Host " ⚠" -ForegroundColor Yellow
            Log-Warn "Portainer服务启动超时"
        }
    }

    # 等待Dashboard服务
    Write-Host "等待Dashboard服务启动..." -NoNewline
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host " ✓" -ForegroundColor Green
                break
            }
        }
        catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
        }
        if ($i -eq 30) {
            Write-Host " ⚠" -ForegroundColor Yellow
            Log-Warn "Dashboard服务启动超时"
        }
    }

    # 显示访问信息
    Write-Host ""
    Write-ColorOutput Green "🎉 可视化管理面板启动完成！"
    Write-ColorOutput Green "=================================="
    Write-Host ""
    Write-Host "📊 访问地址:"
    Write-Host "  🏠 管理面板:     http://localhost:8080"
    Write-Host "  📈 数据面板:     http://localhost:8000/static/"
    Write-Host "  📚 API文档:      http://localhost:8000/docs"
    Write-Host "  🐳 Portainer:    http://localhost:9000"
    Write-Host ""
    Write-Host "🔐 默认账户信息:"
    Write-Host "  Portainer:    admin / $portainerPassword"
    Write-Host ""
    Write-Host "🔧 管理命令:"
    Write-Host "  查看状态:     docker-compose ps"
    Write-Host "  查看日志:     docker-compose logs -f"
    Write-Host "  停止服务:     docker-compose down"
    Write-Host "  重启服务:     docker-compose restart"
    Write-Host ""
    Write-Host "📝 功能说明:"
    Write-Host "  • 管理面板: 统一的系统管理界面"
    Write-Host "  • 数据面板: 农产品价格数据展示"
    Write-Host "  • Portainer: Docker容器可视化管理"
    Write-Host "  • API文档: 接口文档和测试"
    Write-Host ""
    Write-Host "🚀 下一步:"
    Write-Host "  1. 访问管理面板开始使用"
    Write-Host "  2. 在Portainer中管理Docker容器"
    Write-Host "  3. 查看数据面板了解价格信息"
    Write-Host ""

    # 询问是否打开浏览器
    $openBrowser = Read-Host "是否现在打开管理面板? (y/n)"
    if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
        Start-Process "http://localhost:8080"
    }
}

# 运行主函数
try {
    Main
}
catch {
    Log-Error "脚本执行失败: $_"
    Read-Host "按任意键退出"
}
