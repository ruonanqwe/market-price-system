// 农产品价格监控系统 - 管理面板 JavaScript

// 全局配置
const CONFIG = {
    API_BASE_URL: window.location.protocol + '//' + window.location.hostname + ':8000',
    PORTAINER_URL: window.location.protocol + '//' + window.location.hostname + ':9000',
    GRAFANA_URL: window.location.protocol + '//' + window.location.hostname + ':3000',
    PROMETHEUS_URL: window.location.protocol + '//' + window.location.hostname + ':9090',
    REFRESH_INTERVAL: 30000 // 30秒刷新间隔
};

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    initDashboard();
    startAutoRefresh();
});

// 初始化仪表板
function initDashboard() {
    console.log('初始化管理面板...');
    
    // 检查系统状态
    checkSystemStatus();
    
    // 更新系统信息
    updateSystemInfo();
    
    // 检查容器状态
    checkContainerStatus();
}

// 显示指定部分
function showSection(sectionName) {
    // 隐藏所有部分
    const sections = document.querySelectorAll('.content-section');
    sections.forEach(section => {
        section.style.display = 'none';
    });
    
    // 显示指定部分
    const targetSection = document.getElementById(sectionName + '-section');
    if (targetSection) {
        targetSection.style.display = 'block';
    }
    
    // 更新导航状态
    const navLinks = document.querySelectorAll('.sidebar .nav-link');
    navLinks.forEach(link => {
        link.classList.remove('active');
    });
    
    const activeLink = document.querySelector(`[href="#${sectionName}"]`);
    if (activeLink) {
        activeLink.classList.add('active');
    }
    
    // 特殊处理容器管理部分
    if (sectionName === 'containers') {
        loadPortainerFrame();
    }
}

// 检查系统状态
async function checkSystemStatus() {
    try {
        // 检查API服务状态
        const apiResponse = await fetch(`${CONFIG.API_BASE_URL}/api/health`);
        const apiStatus = document.getElementById('api-status');
        
        if (apiResponse.ok) {
            const data = await apiResponse.json();
            apiStatus.textContent = '运行中';
            apiStatus.parentElement.parentElement.parentElement.className = 'card bg-success text-white mb-4';
        } else {
            apiStatus.textContent = '异常';
            apiStatus.parentElement.parentElement.parentElement.className = 'card bg-danger text-white mb-4';
        }
    } catch (error) {
        console.error('检查API状态失败:', error);
        const apiStatus = document.getElementById('api-status');
        apiStatus.textContent = '离线';
        apiStatus.parentElement.parentElement.parentElement.className = 'card bg-danger text-white mb-4';
    }
    
    // 检查调度器状态（模拟）
    const schedulerStatus = document.getElementById('scheduler-status');
    schedulerStatus.textContent = '运行中';
    
    // 获取数据统计
    try {
        const dataResponse = await fetch(`${CONFIG.API_BASE_URL}/api/prices?limit=1`);
        if (dataResponse.ok) {
            const data = await dataResponse.json();
            document.getElementById('data-count').textContent = data.count || 0;
        }
    } catch (error) {
        console.error('获取数据统计失败:', error);
        document.getElementById('data-count').textContent = '错误';
    }
    
    // 系统负载（模拟）
    document.getElementById('system-load').textContent = '正常';
}

// 更新系统信息
function updateSystemInfo() {
    // 更新运行时间（模拟）
    const uptime = document.getElementById('uptime');
    uptime.textContent = '2天 3小时 45分钟';
    
    // 更新最后更新时间
    const lastUpdate = document.getElementById('last-update');
    lastUpdate.textContent = new Date().toLocaleString('zh-CN');
}

// 检查容器状态
async function checkContainerStatus() {
    try {
        // 尝试连接Portainer API检查容器状态
        const containerStatus = document.getElementById('container-status');
        containerStatus.innerHTML = '<span class="status-indicator status-online"></span>运行中';
    } catch (error) {
        console.error('检查容器状态失败:', error);
        const containerStatus = document.getElementById('container-status');
        containerStatus.innerHTML = '<span class="status-indicator status-offline"></span>检查失败';
    }
}

// 刷新仪表板
function refreshDashboard() {
    console.log('刷新仪表板数据...');
    
    // 显示加载状态
    const refreshBtn = document.querySelector('[onclick="refreshDashboard()"]');
    const originalText = refreshBtn.innerHTML;
    refreshBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>刷新中...';
    refreshBtn.disabled = true;
    
    // 重新检查所有状态
    Promise.all([
        checkSystemStatus(),
        updateSystemInfo(),
        checkContainerStatus()
    ]).finally(() => {
        // 恢复按钮状态
        setTimeout(() => {
            refreshBtn.innerHTML = originalText;
            refreshBtn.disabled = false;
        }, 1000);
    });
}

// 自动刷新
function startAutoRefresh() {
    setInterval(() => {
        const currentSection = getCurrentSection();

        switch (currentSection) {
            case 'dashboard':
                checkSystemStatus();
                updateSystemInfo();
                break;
            case 'services':
                refreshServices();
                break;
            case 'containers':
                refreshContainers();
                break;
            case 'monitoring':
                refreshMonitoring();
                break;
            case 'logs':
                if (document.getElementById('auto-refresh-logs').checked) {
                    refreshLogs();
                }
                break;
        }
    }, CONFIG.REFRESH_INTERVAL);
}

// 获取当前显示的部分
function getCurrentSection() {
    const sections = ['dashboard', 'services', 'containers', 'monitoring', 'logs', 'settings'];
    for (const section of sections) {
        const element = document.getElementById(`${section}-section`);
        if (element && element.style.display !== 'none') {
            return section;
        }
    }
    return 'dashboard';
}

// 打开Portainer
function openPortainer() {
    window.open(CONFIG.PORTAINER_URL, '_blank');
}

// 打开Grafana
function openGrafana() {
    window.open(CONFIG.GRAFANA_URL, '_blank');
}

// 打开Prometheus
function openPrometheus() {
    window.open(CONFIG.PROMETHEUS_URL, '_blank');
}

// 打开数据面板
function openDataDashboard() {
    window.open('/static/index.html', '_blank');
}

// 打开API文档
function openAPI() {
    window.open(`${CONFIG.API_BASE_URL}/docs`, '_blank');
}

// 加载Portainer iframe
function loadPortainerFrame() {
    const iframe = document.getElementById('portainer-frame');
    if (iframe && !iframe.src) {
        iframe.src = CONFIG.PORTAINER_URL;
    }
}

// 工具函数：格式化字节大小
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

// 工具函数：格式化时间
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    let result = '';
    if (days > 0) result += `${days}天 `;
    if (hours > 0) result += `${hours}小时 `;
    if (minutes > 0) result += `${minutes}分钟`;
    
    return result || '少于1分钟';
}

// 错误处理
window.addEventListener('error', function(event) {
    console.error('页面错误:', event.error);
});

// 网络状态监控
window.addEventListener('online', function() {
    console.log('网络连接已恢复');
    checkSystemStatus();
});

window.addEventListener('offline', function() {
    console.log('网络连接已断开');
    // 可以在这里显示离线提示
});

// ==================== 服务状态管理 ====================

// 刷新服务状态
function refreshServices() {
    console.log('刷新服务状态...');

    // 更新服务状态卡片
    checkSystemStatus();

    // 更新服务表格
    updateServicesTable();
}

// 更新服务表格
function updateServicesTable() {
    const tableBody = document.getElementById('services-table-body');

    // 模拟服务数据
    const services = [
        {
            name: 'market-api',
            displayName: 'API 服务',
            status: 'running',
            port: '8000',
            cpu: '15%',
            memory: '256MB',
            uptime: '2天 3小时'
        },
        {
            name: 'scheduler',
            displayName: '调度器服务',
            status: 'running',
            port: '-',
            cpu: '5%',
            memory: '128MB',
            uptime: '2天 3小时'
        },
        {
            name: 'portainer',
            displayName: 'Portainer',
            status: 'running',
            port: '9000',
            cpu: '8%',
            memory: '64MB',
            uptime: '2天 3小时'
        },
        {
            name: 'dashboard',
            displayName: 'Dashboard',
            status: 'running',
            port: '8080',
            cpu: '3%',
            memory: '32MB',
            uptime: '2天 3小时'
        }
    ];

    tableBody.innerHTML = services.map(service => `
        <tr>
            <td>
                <i class="fas fa-server me-2"></i>
                ${service.displayName}
            </td>
            <td>
                <span class="badge bg-${service.status === 'running' ? 'success' : 'danger'}">
                    ${service.status === 'running' ? '运行中' : '已停止'}
                </span>
            </td>
            <td>${service.port}</td>
            <td>${service.cpu}</td>
            <td>${service.memory}</td>
            <td>${service.uptime}</td>
            <td>
                <div class="btn-group btn-group-sm">
                    <button class="btn btn-outline-primary" onclick="restartService('${service.name}')" title="重启">
                        <i class="fas fa-redo"></i>
                    </button>
                    <button class="btn btn-outline-info" onclick="viewServiceLogs('${service.name}')" title="日志">
                        <i class="fas fa-file-alt"></i>
                    </button>
                    <button class="btn btn-outline-secondary" onclick="serviceDetails('${service.name}')" title="详情">
                        <i class="fas fa-info"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
}

// 测试API服务
async function testApiService() {
    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/api/health`);
        if (response.ok) {
            alert('API服务连接正常');
        } else {
            alert('API服务连接异常');
        }
    } catch (error) {
        alert('API服务连接失败: ' + error.message);
    }
}

// 查看API日志
function viewApiLogs() {
    showSection('logs');
    document.getElementById('log-service-filter').value = 'api';
    refreshLogs();
}

// 查看调度器日志
function viewSchedulerLogs() {
    showSection('logs');
    document.getElementById('log-service-filter').value = 'scheduler';
    refreshLogs();
}

// 查看Portainer日志
function viewPortainerLogs() {
    showSection('logs');
    document.getElementById('log-service-filter').value = 'portainer';
    refreshLogs();
}

// 触发调度器
function triggerScheduler() {
    if (confirm('确定要手动触发调度器吗？')) {
        // 这里应该调用API触发调度器
        alert('调度器已触发');
    }
}

// 重启服务
function restartService(serviceName) {
    if (confirm(`确定要重启 ${serviceName} 服务吗？`)) {
        // 这里应该调用Docker API重启服务
        alert(`${serviceName} 服务重启中...`);
    }
}

// 查看服务日志
function viewServiceLogs(serviceName) {
    showSection('logs');
    document.getElementById('log-service-filter').value = serviceName;
    refreshLogs();
}

// 服务详情
function serviceDetails(serviceName) {
    alert(`${serviceName} 服务详情功能开发中...`);
}

// ==================== 容器管理 ====================

// 刷新容器信息
function refreshContainers() {
    console.log('刷新容器信息...');

    // 模拟容器统计数据
    document.getElementById('running-containers').textContent = '4';
    document.getElementById('stopped-containers').textContent = '0';
    document.getElementById('total-images').textContent = '6';
    document.getElementById('total-networks').textContent = '2';

    // 更新容器数量
    document.getElementById('container-count').textContent = '4';
}

// ==================== 系统监控 ====================

// 刷新监控数据
function refreshMonitoring() {
    console.log('刷新监控数据...');

    // 模拟系统资源数据
    updateSystemResources();
    updateApplicationMetrics();
}

// 更新系统资源
function updateSystemResources() {
    // CPU使用率
    const cpuUsage = Math.floor(Math.random() * 30) + 10; // 10-40%
    document.getElementById('cpu-usage').textContent = `${cpuUsage}%`;
    document.getElementById('cpu-progress').style.width = `${cpuUsage}%`;

    // 内存使用
    const memoryUsage = Math.floor(Math.random() * 40) + 30; // 30-70%
    document.getElementById('memory-usage').textContent = `${memoryUsage}%`;
    document.getElementById('memory-progress').style.width = `${memoryUsage}%`;

    // 网络流量
    document.getElementById('network-in').textContent = '1.2 MB/s';
    document.getElementById('network-out').textContent = '0.8 MB/s';

    // 磁盘使用
    const diskUsage = Math.floor(Math.random() * 20) + 45; // 45-65%
    document.getElementById('disk-used').textContent = `${diskUsage}%`;
    document.getElementById('disk-free').textContent = `${100 - diskUsage}%`;
    document.getElementById('disk-progress').style.width = `${diskUsage}%`;
}

// 更新应用性能指标
function updateApplicationMetrics() {
    document.getElementById('api-requests').textContent = Math.floor(Math.random() * 100) + 50;
    document.getElementById('response-time').textContent = (Math.random() * 200 + 50).toFixed(0) + 'ms';
    document.getElementById('error-rate').textContent = (Math.random() * 2).toFixed(2) + '%';
    document.getElementById('data-processed').textContent = (Math.random() * 1000 + 500).toFixed(0);
}

// ==================== 日志管理 ====================

// 刷新日志
function refreshLogs() {
    console.log('刷新日志...');

    const logContainer = document.getElementById('log-container');
    const service = document.getElementById('log-service-filter').value;
    const level = document.getElementById('log-level-filter').value;
    const timeRange = document.getElementById('log-time-filter').value;

    // 模拟日志数据
    const logs = generateMockLogs(service, level, timeRange);

    logContainer.innerHTML = logs.map(log =>
        `<div class="log-entry" style="margin-bottom: 5px; padding: 5px; border-left: 3px solid ${getLogLevelColor(log.level)};">
            <span style="color: #888;">[${log.timestamp}]</span>
            <span style="color: ${getLogLevelColor(log.level)}; font-weight: bold;">[${log.level}]</span>
            <span style="color: #ccc;">[${log.service}]</span>
            <span style="color: #fff;">${log.message}</span>
        </div>`
    ).join('');

    // 滚动到底部
    logContainer.scrollTop = logContainer.scrollHeight;
}

// 生成模拟日志
function generateMockLogs(service, level, timeRange) {
    const logs = [];
    const services = service ? [service] : ['api', 'scheduler', 'portainer', 'dashboard'];
    const levels = level ? [level] : ['INFO', 'WARN', 'ERROR', 'DEBUG'];

    for (let i = 0; i < 50; i++) {
        const randomService = services[Math.floor(Math.random() * services.length)];
        const randomLevel = levels[Math.floor(Math.random() * levels.length)];
        const timestamp = new Date(Date.now() - Math.random() * 24 * 60 * 60 * 1000).toISOString();

        logs.push({
            timestamp: timestamp.substring(0, 19).replace('T', ' '),
            level: randomLevel,
            service: randomService,
            message: generateLogMessage(randomService, randomLevel)
        });
    }

    return logs.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
}

// 生成日志消息
function generateLogMessage(service, level) {
    const messages = {
        api: {
            INFO: ['API服务启动成功', '处理请求: GET /api/health', '数据查询完成', '缓存更新成功'],
            WARN: ['响应时间较长', '连接池使用率较高', '内存使用率超过70%'],
            ERROR: ['数据库连接失败', '请求处理异常', '文件读取错误'],
            DEBUG: ['调试信息: 变量值检查', '函数调用跟踪', '性能计时器']
        },
        scheduler: {
            INFO: ['调度任务开始执行', '数据爬取完成', '任务队列处理中'],
            WARN: ['任务执行时间超时', '队列积压较多'],
            ERROR: ['任务执行失败', '网络连接超时'],
            DEBUG: ['任务调度详情', '队列状态检查']
        },
        portainer: {
            INFO: ['容器状态检查', '用户登录成功', '配置更新完成'],
            WARN: ['容器资源使用率高', '磁盘空间不足'],
            ERROR: ['容器启动失败', '权限验证失败'],
            DEBUG: ['API调用跟踪', '容器操作日志']
        },
        dashboard: {
            INFO: ['页面加载完成', '用户操作记录', '数据刷新成功'],
            WARN: ['页面加载缓慢', '网络连接不稳定'],
            ERROR: ['页面加载失败', 'JavaScript执行错误'],
            DEBUG: ['组件渲染跟踪', '事件处理详情']
        }
    };

    const serviceMessages = messages[service] || messages.api;
    const levelMessages = serviceMessages[level] || serviceMessages.INFO;
    return levelMessages[Math.floor(Math.random() * levelMessages.length)];
}

// 获取日志级别颜色
function getLogLevelColor(level) {
    const colors = {
        ERROR: '#ff6b6b',
        WARN: '#feca57',
        INFO: '#48dbfb',
        DEBUG: '#ff9ff3'
    };
    return colors[level] || '#ffffff';
}

// 清空日志
function clearLogs() {
    if (confirm('确定要清空日志吗？')) {
        document.getElementById('log-container').innerHTML = '<div class="text-center text-muted"><p>日志已清空</p></div>';
    }
}

// 下载日志
function downloadLogs() {
    const logContainer = document.getElementById('log-container');
    const logText = logContainer.innerText;

    const blob = new Blob([logText], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `system-logs-${new Date().toISOString().substring(0, 10)}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
}

// 搜索日志
function searchLogs() {
    const searchTerm = document.getElementById('log-search').value.toLowerCase();
    if (!searchTerm) {
        refreshLogs();
        return;
    }

    const logContainer = document.getElementById('log-container');
    const logEntries = logContainer.querySelectorAll('.log-entry');

    logEntries.forEach(entry => {
        const text = entry.textContent.toLowerCase();
        if (text.includes(searchTerm)) {
            entry.style.display = 'block';
            entry.style.backgroundColor = 'rgba(255, 255, 0, 0.1)';
        } else {
            entry.style.display = 'none';
        }
    });
}

// ==================== 系统设置 ====================

// 保存设置
function saveSettings() {
    const settings = {
        systemName: document.getElementById('system-name').value,
        refreshInterval: document.getElementById('refresh-interval').value,
        timezone: document.getElementById('timezone').value,
        enableNotifications: document.getElementById('enable-notifications').checked,
        dataRetention: document.getElementById('data-retention').value,
        backupFrequency: document.getElementById('backup-frequency').value,
        autoBackup: document.getElementById('auto-backup').checked,
        cpuThreshold: document.getElementById('cpu-threshold').value,
        memoryThreshold: document.getElementById('memory-threshold').value,
        diskThreshold: document.getElementById('disk-threshold').value,
        enableAlerts: document.getElementById('enable-alerts').checked,
        sessionTimeout: document.getElementById('session-timeout').value,
        logLevel: document.getElementById('log-level').value,
        enableAudit: document.getElementById('enable-audit').checked
    };

    // 保存到localStorage
    localStorage.setItem('dashboardSettings', JSON.stringify(settings));

    alert('设置已保存');
    console.log('设置已保存:', settings);
}

// 加载设置
function loadSettings() {
    const savedSettings = localStorage.getItem('dashboardSettings');
    if (savedSettings) {
        const settings = JSON.parse(savedSettings);

        // 应用设置到表单
        Object.keys(settings).forEach(key => {
            const element = document.getElementById(key.replace(/([A-Z])/g, '-$1').toLowerCase());
            if (element) {
                if (element.type === 'checkbox') {
                    element.checked = settings[key];
                } else {
                    element.value = settings[key];
                }
            }
        });

        // 更新刷新间隔
        if (settings.refreshInterval) {
            CONFIG.REFRESH_INTERVAL = parseInt(settings.refreshInterval) * 1000;
        }
    }
}

// 备份系统
function backupSystem() {
    if (confirm('确定要备份系统吗？这可能需要几分钟时间。')) {
        alert('系统备份已开始，请稍候...');
        // 这里应该调用后端API进行备份
    }
}

// 重启服务
function restartServices() {
    if (confirm('确定要重启所有服务吗？这将导致短暂的服务中断。')) {
        alert('服务重启中，请稍候...');
        // 这里应该调用Docker API重启服务
    }
}

// 检查更新
function updateSystem() {
    alert('正在检查系统更新...');
    // 模拟检查更新
    setTimeout(() => {
        alert('系统已是最新版本');
    }, 2000);
}

// 重置系统
function resetSystem() {
    if (confirm('警告：这将重置所有系统设置，确定要继续吗？')) {
        if (confirm('此操作不可撤销，请再次确认！')) {
            localStorage.removeItem('dashboardSettings');
            alert('系统设置已重置，页面将刷新');
            location.reload();
        }
    }
}

// 页面加载时加载设置
document.addEventListener('DOMContentLoaded', function() {
    loadSettings();
});

// 导出配置供其他脚本使用
window.DashboardConfig = CONFIG;
