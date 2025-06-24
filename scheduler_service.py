#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
定时任务服务
负责定时爬取数据、数据清理、统计分析等任务
"""

import schedule
import time
import threading
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Callable
import json
import os
from market_crawler import MarketCrawler
from database_manager import DatabaseManager
from location_service import LocationService
import requests
import signal
import sys

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scheduler.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SchedulerService:
    def __init__(self, config_file: str = "scheduler_config.json"):
        self.config_file = config_file
        self.config = self.load_config()
        self.crawler = MarketCrawler()
        self.db_manager = DatabaseManager()
        self.location_service = LocationService()
        self.running = False
        self.scheduler_thread = None
        
        # 任务统计
        self.task_stats = {
            "crawl_data": {"success": 0, "failed": 0, "last_run": None},
            "cleanup_data": {"success": 0, "failed": 0, "last_run": None},
            "generate_reports": {"success": 0, "failed": 0, "last_run": None},
            "health_check": {"success": 0, "failed": 0, "last_run": None}
        }
        
        # 注册信号处理
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def load_config(self) -> Dict:
        """加载配置文件"""
        default_config = {
            "crawl_interval_minutes": 30,
            "cleanup_interval_hours": 24,
            "report_interval_hours": 6,
            "health_check_interval_minutes": 5,
            "data_retention_days": 90,
            "max_retry_attempts": 3,
            "retry_delay_seconds": 60,
            "enable_notifications": False,
            "notification_webhook": "",
            "provinces_to_crawl": [],  # 空列表表示爬取所有省份
            "priority_varieties": ["白萝卜", "土豆", "白菜", "西红柿", "黄瓜"],
            "performance_monitoring": True
        }
        
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    user_config = json.load(f)
                    default_config.update(user_config)
                    logger.info(f"已加载配置文件: {self.config_file}")
            except Exception as e:
                logger.error(f"加载配置文件失败: {str(e)}, 使用默认配置")
        else:
            # 创建默认配置文件
            self.save_config(default_config)
            logger.info(f"已创建默认配置文件: {self.config_file}")
        
        return default_config
    
    def save_config(self, config: Dict):
        """保存配置文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存配置文件失败: {str(e)}")
    
    def signal_handler(self, signum, frame):
        """信号处理器"""
        logger.info(f"接收到信号 {signum}, 正在关闭服务...")
        self.stop()
        sys.exit(0)
    
    def crawl_market_data(self):
        """爬取市场数据任务"""
        task_name = "crawl_data"
        start_time = datetime.now()
        
        try:
            logger.info("开始执行数据爬取任务...")
            
            # 确定要爬取的省份
            provinces_to_crawl = self.config.get("provinces_to_crawl", [])
            if not provinces_to_crawl:
                provinces_to_crawl = self.crawler.provinces
            else:
                # 根据省份名称筛选
                provinces_to_crawl = [
                    p for p in self.crawler.provinces 
                    if p["name"] in provinces_to_crawl
                ]
            
            all_data = []
            successful_provinces = 0
            
            for province in provinces_to_crawl:
                try:
                    province_code = province["code"]
                    province_name = province["name"]
                    
                    logger.info(f"正在爬取 {province_name} 的数据...")
                    
                    # 获取该省份的市场列表
                    url = f"{self.crawler.base_url}/priceQuotationController/getTodayMarketByProvinceCode"
                    params = {"code": province_code}
                    
                    response = requests.post(
                        url, 
                        headers=self.crawler.headers, 
                        params=params,
                        verify=False,
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        data = response.json()
                        if data.get("code") == 200 and "content" in data:
                            markets = data["content"]
                            
                            province_data = []
                            for market in markets:
                                market_id = market.get("marketId")
                                market_name = market.get("marketName")
                                
                                if market_id and market_name:
                                    try:
                                        details = self.crawler.fetch_market_details(market_id)
                                        if details:
                                            # 添加省份信息
                                            for detail in details:
                                                detail["省份"] = province_name
                                                detail["省份代码"] = province_code
                                            province_data.extend(details)
                                        
                                        time.sleep(1)  # 避免请求过快
                                    except Exception as e:
                                        logger.error(f"获取市场 {market_name} 详情失败: {str(e)}")
                                        continue
                            
                            all_data.extend(province_data)
                            successful_provinces += 1
                            logger.info(f"{province_name} 爬取完成，获得 {len(province_data)} 条数据")
                    
                    time.sleep(2)  # 省份间隔
                    
                except Exception as e:
                    logger.error(f"爬取 {province_name} 失败: {str(e)}")
                    continue
            
            # 保存数据到数据库
            if all_data:
                inserted_count = self.db_manager.insert_market_data(all_data)
                
                # 发送通知
                if self.config.get("enable_notifications"):
                    self.send_notification(
                        f"数据爬取完成",
                        f"成功爬取 {successful_provinces} 个省份，共 {inserted_count} 条数据"
                    )
                
                logger.info(f"数据爬取任务完成: {successful_provinces} 个省份, {inserted_count} 条数据")
            else:
                logger.warning("本次爬取未获得任何数据")
            
            # 更新任务统计
            self.task_stats[task_name]["success"] += 1
            self.task_stats[task_name]["last_run"] = start_time.isoformat()
            
        except Exception as e:
            logger.error(f"数据爬取任务失败: {str(e)}")
            self.task_stats[task_name]["failed"] += 1
            
            if self.config.get("enable_notifications"):
                self.send_notification("数据爬取失败", str(e))
    
    def cleanup_old_data(self):
        """清理旧数据任务"""
        task_name = "cleanup_data"
        start_time = datetime.now()
        
        try:
            logger.info("开始执行数据清理任务...")
            
            retention_days = self.config.get("data_retention_days", 90)
            result = self.db_manager.cleanup_old_data(retention_days)
            
            logger.info(f"数据清理完成: {result}")
            
            # 发送通知
            if self.config.get("enable_notifications"):
                self.send_notification(
                    "数据清理完成",
                    f"删除了 {result['deleted_prices']} 条价格数据"
                )
            
            self.task_stats[task_name]["success"] += 1
            self.task_stats[task_name]["last_run"] = start_time.isoformat()
            
        except Exception as e:
            logger.error(f"数据清理任务失败: {str(e)}")
            self.task_stats[task_name]["failed"] += 1
    
    def generate_daily_report(self):
        """生成日报任务"""
        task_name = "generate_reports"
        start_time = datetime.now()
        
        try:
            logger.info("开始生成日报...")
            
            # 获取今日统计
            today_stats = self.db_manager.get_price_statistics(days=1)
            week_stats = self.db_manager.get_price_statistics(days=7)
            
            # 重点品种价格分析
            priority_varieties = self.config.get("priority_varieties", [])
            variety_analysis = {}
            
            for variety in priority_varieties:
                try:
                    variety_stats = self.db_manager.get_price_statistics(
                        variety_name=variety, days=7
                    )
                    variety_analysis[variety] = variety_stats
                except Exception as e:
                    logger.error(f"分析品种 {variety} 失败: {str(e)}")
            
            # 生成报告
            report = {
                "report_date": start_time.strftime("%Y-%m-%d"),
                "today_summary": today_stats,
                "week_summary": week_stats,
                "variety_analysis": variety_analysis,
                "task_statistics": self.task_stats,
                "generated_at": start_time.isoformat()
            }
            
            # 保存报告
            report_file = f"reports/daily_report_{start_time.strftime('%Y%m%d')}.json"
            os.makedirs("reports", exist_ok=True)
            
            with open(report_file, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            
            logger.info(f"日报已生成: {report_file}")
            
            # 发送通知
            if self.config.get("enable_notifications"):
                summary = f"今日数据: {today_stats['total_records']} 条记录, " \
                         f"平均价格: {today_stats['price_range']['avg']} 元"
                self.send_notification("日报生成完成", summary)
            
            self.task_stats[task_name]["success"] += 1
            self.task_stats[task_name]["last_run"] = start_time.isoformat()
            
        except Exception as e:
            logger.error(f"生成日报失败: {str(e)}")
            self.task_stats[task_name]["failed"] += 1
    
    def health_check(self):
        """健康检查任务"""
        task_name = "health_check"
        start_time = datetime.now()
        
        try:
            # 检查数据库连接
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM market_prices WHERE DATE(crawl_time) = DATE('now')")
                today_count = cursor.fetchone()[0]
            
            # 检查最近数据更新时间
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT MAX(crawl_time) FROM market_prices")
                last_update = cursor.fetchone()[0]
            
            # 健康状态评估
            health_status = "healthy"
            issues = []
            
            if today_count == 0:
                health_status = "warning"
                issues.append("今日无数据更新")
            
            if last_update:
                last_update_time = datetime.fromisoformat(last_update)
                if datetime.now() - last_update_time > timedelta(hours=2):
                    health_status = "warning"
                    issues.append("数据更新延迟超过2小时")
            
            health_info = {
                "status": health_status,
                "today_records": today_count,
                "last_update": last_update,
                "issues": issues,
                "check_time": start_time.isoformat()
            }
            
            # 保存健康检查结果
            with open("health_status.json", 'w', encoding='utf-8') as f:
                json.dump(health_info, f, ensure_ascii=False, indent=2)
            
            if health_status != "healthy":
                logger.warning(f"健康检查发现问题: {issues}")
                if self.config.get("enable_notifications"):
                    self.send_notification("系统健康警告", "; ".join(issues))
            
            self.task_stats[task_name]["success"] += 1
            self.task_stats[task_name]["last_run"] = start_time.isoformat()
            
        except Exception as e:
            logger.error(f"健康检查失败: {str(e)}")
            self.task_stats[task_name]["failed"] += 1
    
    def send_notification(self, title: str, message: str):
        """发送通知"""
        if not self.config.get("enable_notifications"):
            return
        
        webhook_url = self.config.get("notification_webhook")
        if not webhook_url:
            return
        
        try:
            payload = {
                "title": title,
                "message": message,
                "timestamp": datetime.now().isoformat(),
                "service": "农产品价格监控系统"
            }
            
            response = requests.post(webhook_url, json=payload, timeout=10)
            if response.status_code == 200:
                logger.info(f"通知发送成功: {title}")
            else:
                logger.warning(f"通知发送失败: HTTP {response.status_code}")
                
        except Exception as e:
            logger.error(f"发送通知失败: {str(e)}")
    
    def setup_schedules(self):
        """设置定时任务"""
        # 数据爬取任务
        crawl_interval = self.config.get("crawl_interval_minutes", 30)
        schedule.every(crawl_interval).minutes.do(self.crawl_market_data)
        
        # 数据清理任务
        cleanup_interval = self.config.get("cleanup_interval_hours", 24)
        schedule.every(cleanup_interval).hours.do(self.cleanup_old_data)
        
        # 报告生成任务
        report_interval = self.config.get("report_interval_hours", 6)
        schedule.every(report_interval).hours.do(self.generate_daily_report)
        
        # 健康检查任务
        health_interval = self.config.get("health_check_interval_minutes", 5)
        schedule.every(health_interval).minutes.do(self.health_check)
        
        logger.info("定时任务已设置:")
        logger.info(f"- 数据爬取: 每 {crawl_interval} 分钟")
        logger.info(f"- 数据清理: 每 {cleanup_interval} 小时")
        logger.info(f"- 报告生成: 每 {report_interval} 小时")
        logger.info(f"- 健康检查: 每 {health_interval} 分钟")
    
    def run_scheduler(self):
        """运行调度器"""
        while self.running:
            try:
                schedule.run_pending()
                time.sleep(1)
            except Exception as e:
                logger.error(f"调度器运行错误: {str(e)}")
                time.sleep(5)
    
    def start(self):
        """启动服务"""
        if self.running:
            logger.warning("服务已在运行中")
            return
        
        logger.info("启动定时任务服务...")
        self.running = True
        
        # 设置定时任务
        self.setup_schedules()
        
        # 启动调度器线程
        self.scheduler_thread = threading.Thread(target=self.run_scheduler, daemon=True)
        self.scheduler_thread.start()
        
        # 立即执行一次健康检查
        self.health_check()
        
        logger.info("定时任务服务已启动")
    
    def stop(self):
        """停止服务"""
        if not self.running:
            return
        
        logger.info("正在停止定时任务服务...")
        self.running = False
        
        if self.scheduler_thread and self.scheduler_thread.is_alive():
            self.scheduler_thread.join(timeout=5)
        
        logger.info("定时任务服务已停止")
    
    def get_status(self) -> Dict:
        """获取服务状态"""
        return {
            "running": self.running,
            "config": self.config,
            "task_stats": self.task_stats,
            "next_runs": {
                "crawl_data": schedule.next_run().isoformat() if schedule.jobs else None
            }
        }

def main():
    """主函数"""
    scheduler = SchedulerService()
    
    try:
        scheduler.start()
        
        # 保持主线程运行
        while True:
            time.sleep(60)
            
    except KeyboardInterrupt:
        logger.info("接收到中断信号")
    finally:
        scheduler.stop()

if __name__ == "__main__":
    main()
