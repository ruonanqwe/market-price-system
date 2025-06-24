#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据库管理器
提供数据库初始化、数据迁移、性能优化等功能
"""

import sqlite3
import os
import logging
import json
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Any
import threading
from contextlib import contextmanager

logger = logging.getLogger(__name__)

class DatabaseManager:
    def __init__(self, db_path: str = "market_data.db"):
        self.db_path = db_path
        self.lock = threading.Lock()
        self.init_database()
    
    @contextmanager
    def get_connection(self):
        """获取数据库连接的上下文管理器"""
        conn = None
        try:
            conn = sqlite3.connect(self.db_path, timeout=30.0)
            conn.execute("PRAGMA journal_mode=WAL")  # 启用WAL模式提高并发性能
            conn.execute("PRAGMA synchronous=NORMAL")  # 平衡性能和安全性
            conn.execute("PRAGMA cache_size=10000")  # 增加缓存大小
            conn.execute("PRAGMA temp_store=MEMORY")  # 临时表存储在内存中
            yield conn
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()
    
    def init_database(self):
        """初始化数据库结构"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # 创建市场价格表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS market_prices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    market_id TEXT NOT NULL,
                    market_code TEXT,
                    market_name TEXT NOT NULL,
                    market_type TEXT,
                    variety_id TEXT,
                    variety_name TEXT NOT NULL,
                    min_price REAL DEFAULT 0,
                    avg_price REAL DEFAULT 0,
                    max_price REAL DEFAULT 0,
                    unit TEXT,
                    trade_date TEXT NOT NULL,
                    trade_volume REAL DEFAULT 0,
                    produce_place TEXT,
                    sale_place TEXT,
                    province TEXT,
                    province_code TEXT,
                    area_name TEXT,
                    area_code TEXT,
                    variety_type TEXT,
                    variety_type_id TEXT,
                    crawl_time TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(market_id, variety_id, trade_date)
                )
            ''')
            
            # 创建价格历史表（用于存储历史价格变化）
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS price_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    market_id TEXT NOT NULL,
                    variety_id TEXT NOT NULL,
                    price_date TEXT NOT NULL,
                    min_price REAL DEFAULT 0,
                    avg_price REAL DEFAULT 0,
                    max_price REAL DEFAULT 0,
                    price_change REAL DEFAULT 0,
                    change_rate REAL DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(market_id, variety_id, price_date)
                )
            ''')
            
            # 创建市场信息表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS markets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    market_id TEXT UNIQUE NOT NULL,
                    market_code TEXT,
                    market_name TEXT NOT NULL,
                    market_type TEXT,
                    province TEXT,
                    province_code TEXT,
                    area_name TEXT,
                    area_code TEXT,
                    address TEXT,
                    latitude REAL,
                    longitude REAL,
                    contact_info TEXT,
                    status TEXT DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # 创建品种信息表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS varieties (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    variety_id TEXT UNIQUE NOT NULL,
                    variety_name TEXT NOT NULL,
                    variety_type TEXT,
                    variety_type_id TEXT,
                    category TEXT,
                    unit TEXT,
                    description TEXT,
                    status TEXT DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # 创建数据统计表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS data_statistics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    stat_date TEXT NOT NULL,
                    total_records INTEGER DEFAULT 0,
                    total_markets INTEGER DEFAULT 0,
                    total_varieties INTEGER DEFAULT 0,
                    total_provinces INTEGER DEFAULT 0,
                    avg_price_all REAL DEFAULT 0,
                    price_updates INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(stat_date)
                )
            ''')
            
            # 创建索引
            self._create_indexes(cursor)
            
            # 创建触发器
            self._create_triggers(cursor)
            
            conn.commit()
            logger.info("数据库初始化完成")
    
    def _create_indexes(self, cursor):
        """创建数据库索引"""
        indexes = [
            # 市场价格表索引
            "CREATE INDEX IF NOT EXISTS idx_market_prices_province ON market_prices(province)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_market_name ON market_prices(market_name)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_variety_name ON market_prices(variety_name)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_trade_date ON market_prices(trade_date)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_crawl_time ON market_prices(crawl_time)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_avg_price ON market_prices(avg_price)",
            "CREATE INDEX IF NOT EXISTS idx_market_prices_composite ON market_prices(province, variety_name, trade_date)",
            
            # 价格历史表索引
            "CREATE INDEX IF NOT EXISTS idx_price_history_market_variety ON price_history(market_id, variety_id)",
            "CREATE INDEX IF NOT EXISTS idx_price_history_date ON price_history(price_date)",
            
            # 市场信息表索引
            "CREATE INDEX IF NOT EXISTS idx_markets_province ON markets(province)",
            "CREATE INDEX IF NOT EXISTS idx_markets_location ON markets(latitude, longitude)",
            
            # 品种信息表索引
            "CREATE INDEX IF NOT EXISTS idx_varieties_name ON varieties(variety_name)",
            "CREATE INDEX IF NOT EXISTS idx_varieties_type ON varieties(variety_type)",
        ]
        
        for index_sql in indexes:
            try:
                cursor.execute(index_sql)
            except Exception as e:
                logger.warning(f"创建索引失败: {index_sql}, 错误: {str(e)}")
    
    def _create_triggers(self, cursor):
        """创建数据库触发器"""
        # 更新时间触发器
        cursor.execute('''
            CREATE TRIGGER IF NOT EXISTS update_market_prices_timestamp 
            AFTER UPDATE ON market_prices
            BEGIN
                UPDATE market_prices SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
            END
        ''')
        
        cursor.execute('''
            CREATE TRIGGER IF NOT EXISTS update_markets_timestamp 
            AFTER UPDATE ON markets
            BEGIN
                UPDATE markets SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
            END
        ''')
    
    def insert_market_data(self, data_list: List[Dict]) -> int:
        """批量插入市场数据"""
        if not data_list:
            return 0
        
        inserted_count = 0
        with self.lock:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                try:
                    for data in data_list:
                        # 插入或更新市场价格数据
                        cursor.execute('''
                            INSERT OR REPLACE INTO market_prices (
                                market_id, market_code, market_name, market_type,
                                variety_id, variety_name, min_price, avg_price, max_price,
                                unit, trade_date, trade_volume, produce_place, sale_place,
                                province, province_code, area_name, area_code,
                                variety_type, variety_type_id, crawl_time
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ''', (
                            data.get('市场ID', ''),
                            data.get('市场代码', ''),
                            data.get('市场名称', ''),
                            data.get('市场类型', ''),
                            data.get('品种ID', ''),
                            data.get('品种名称', ''),
                            float(data.get('最低价', 0) or 0),
                            float(data.get('平均价', 0) or 0),
                            float(data.get('最高价', 0) or 0),
                            data.get('计量单位', ''),
                            data.get('交易日期', ''),
                            float(data.get('交易量', 0) or 0),
                            data.get('产地', ''),
                            data.get('销售地', ''),
                            data.get('省份', ''),
                            data.get('省份代码', ''),
                            data.get('地区名称', ''),
                            data.get('地区代码', ''),
                            data.get('品种类型', ''),
                            data.get('品种类型ID', ''),
                            data.get('爬取时间', '')
                        ))
                        
                        # 同时更新市场信息表
                        if data.get('市场ID') and data.get('市场名称'):
                            cursor.execute('''
                                INSERT OR IGNORE INTO markets (
                                    market_id, market_code, market_name, market_type,
                                    province, province_code, area_name, area_code
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            ''', (
                                data.get('市场ID', ''),
                                data.get('市场代码', ''),
                                data.get('市场名称', ''),
                                data.get('市场类型', ''),
                                data.get('省份', ''),
                                data.get('省份代码', ''),
                                data.get('地区名称', ''),
                                data.get('地区代码', '')
                            ))
                        
                        # 同时更新品种信息表
                        if data.get('品种ID') and data.get('品种名称'):
                            cursor.execute('''
                                INSERT OR IGNORE INTO varieties (
                                    variety_id, variety_name, variety_type, variety_type_id, unit
                                ) VALUES (?, ?, ?, ?, ?)
                            ''', (
                                data.get('品种ID', ''),
                                data.get('品种名称', ''),
                                data.get('品种类型', ''),
                                data.get('品种类型ID', ''),
                                data.get('计量单位', '')
                            ))
                        
                        inserted_count += 1
                    
                    conn.commit()
                    logger.info(f"成功插入 {inserted_count} 条数据")
                    
                    # 更新统计信息
                    self._update_statistics(cursor)
                    conn.commit()
                    
                except Exception as e:
                    conn.rollback()
                    logger.error(f"插入数据失败: {str(e)}")
                    raise
        
        return inserted_count
    
    def _update_statistics(self, cursor):
        """更新数据统计"""
        today = datetime.now().strftime('%Y-%m-%d')
        
        # 计算统计数据
        cursor.execute("SELECT COUNT(*) FROM market_prices")
        total_records = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(DISTINCT market_name) FROM market_prices")
        total_markets = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(DISTINCT variety_name) FROM market_prices")
        total_varieties = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(DISTINCT province) FROM market_prices")
        total_provinces = cursor.fetchone()[0]
        
        cursor.execute("SELECT AVG(avg_price) FROM market_prices WHERE avg_price > 0")
        avg_price_result = cursor.fetchone()[0]
        avg_price_all = float(avg_price_result) if avg_price_result else 0
        
        cursor.execute("SELECT COUNT(*) FROM market_prices WHERE DATE(crawl_time) = ?", (today,))
        price_updates = cursor.fetchone()[0]
        
        # 插入或更新统计数据
        cursor.execute('''
            INSERT OR REPLACE INTO data_statistics (
                stat_date, total_records, total_markets, total_varieties,
                total_provinces, avg_price_all, price_updates
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (today, total_records, total_markets, total_varieties, 
              total_provinces, avg_price_all, price_updates))
    
    def query_prices(self, filters: Dict[str, Any], limit: int = 100) -> List[Dict]:
        """查询价格数据"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # 构建查询条件
            conditions = []
            params = []
            
            if filters.get('province'):
                conditions.append("province LIKE ?")
                params.append(f"%{filters['province']}%")
            
            if filters.get('market_name'):
                conditions.append("market_name LIKE ?")
                params.append(f"%{filters['market_name']}%")
            
            if filters.get('variety_name'):
                conditions.append("variety_name LIKE ?")
                params.append(f"%{filters['variety_name']}%")
            
            if filters.get('start_date'):
                conditions.append("trade_date >= ?")
                params.append(filters['start_date'])
            
            if filters.get('end_date'):
                conditions.append("trade_date <= ?")
                params.append(filters['end_date'])
            
            if filters.get('min_price'):
                conditions.append("avg_price >= ?")
                params.append(filters['min_price'])
            
            if filters.get('max_price'):
                conditions.append("avg_price <= ?")
                params.append(filters['max_price'])
            
            where_clause = " AND ".join(conditions) if conditions else "1=1"
            
            sql = f'''
                SELECT * FROM market_prices 
                WHERE {where_clause}
                ORDER BY trade_date DESC, crawl_time DESC
                LIMIT ?
            '''
            params.append(limit)
            
            try:
                cursor.execute(sql, params)
                columns = [description[0] for description in cursor.description]
                results = []
                
                for row in cursor.fetchall():
                    result = dict(zip(columns, row))
                    results.append(result)
                
                return results
                
            except Exception as e:
                logger.error(f"查询数据失败: {str(e)}")
                raise
    
    def get_price_statistics(self, variety_name: str = None, province: str = None, days: int = 30) -> Dict:
        """获取价格统计信息"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            conditions = ["avg_price > 0"]
            params = []
            
            if variety_name:
                conditions.append("variety_name LIKE ?")
                params.append(f"%{variety_name}%")
            
            if province:
                conditions.append("province LIKE ?")
                params.append(f"%{province}%")
            
            if days > 0:
                conditions.append("trade_date >= date('now', '-{} days')".format(days))
            
            where_clause = " AND ".join(conditions)
            
            # 基本统计
            cursor.execute(f'''
                SELECT 
                    COUNT(*) as total_records,
                    COUNT(DISTINCT market_name) as total_markets,
                    COUNT(DISTINCT variety_name) as total_varieties,
                    MIN(avg_price) as min_price,
                    MAX(avg_price) as max_price,
                    AVG(avg_price) as avg_price,
                    MIN(trade_date) as earliest_date,
                    MAX(trade_date) as latest_date
                FROM market_prices 
                WHERE {where_clause}
            ''', params)
            
            stats = cursor.fetchone()
            
            # 价格分布
            cursor.execute(f'''
                SELECT 
                    CASE 
                        WHEN avg_price < 1 THEN '0-1元'
                        WHEN avg_price < 5 THEN '1-5元'
                        WHEN avg_price < 10 THEN '5-10元'
                        WHEN avg_price < 20 THEN '10-20元'
                        WHEN avg_price < 50 THEN '20-50元'
                        ELSE '50元以上'
                    END as price_range,
                    COUNT(*) as count
                FROM market_prices 
                WHERE {where_clause}
                GROUP BY price_range
                ORDER BY MIN(avg_price)
            ''', params)
            
            price_distribution = dict(cursor.fetchall())
            
            return {
                "total_records": stats[0],
                "total_markets": stats[1],
                "total_varieties": stats[2],
                "price_range": {
                    "min": float(stats[3]) if stats[3] else 0,
                    "max": float(stats[4]) if stats[4] else 0,
                    "avg": round(float(stats[5]), 2) if stats[5] else 0
                },
                "date_range": {
                    "earliest": stats[6],
                    "latest": stats[7]
                },
                "price_distribution": price_distribution,
                "query_params": {
                    "variety_name": variety_name,
                    "province": province,
                    "days": days
                }
            }
    
    def cleanup_old_data(self, days: int = 90):
        """清理旧数据"""
        with self.lock:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                cutoff_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
                
                # 删除旧的价格数据
                cursor.execute("DELETE FROM market_prices WHERE trade_date < ?", (cutoff_date,))
                deleted_prices = cursor.rowcount
                
                # 删除旧的价格历史
                cursor.execute("DELETE FROM price_history WHERE price_date < ?", (cutoff_date,))
                deleted_history = cursor.rowcount
                
                # 删除旧的统计数据
                cursor.execute("DELETE FROM data_statistics WHERE stat_date < ?", (cutoff_date,))
                deleted_stats = cursor.rowcount
                
                conn.commit()
                
                # 优化数据库
                cursor.execute("VACUUM")
                
                logger.info(f"清理完成: 删除 {deleted_prices} 条价格数据, {deleted_history} 条历史数据, {deleted_stats} 条统计数据")
                
                return {
                    "deleted_prices": deleted_prices,
                    "deleted_history": deleted_history,
                    "deleted_stats": deleted_stats,
                    "cutoff_date": cutoff_date
                }
    
    def export_data(self, output_file: str, format: str = "csv", filters: Dict = None):
        """导出数据"""
        filters = filters or {}
        data = self.query_prices(filters, limit=10000)
        
        if not data:
            logger.warning("没有数据可导出")
            return
        
        df = pd.DataFrame(data)
        
        if format.lower() == "csv":
            df.to_csv(output_file, index=False, encoding='utf-8-sig')
        elif format.lower() == "json":
            df.to_json(output_file, orient='records', force_ascii=False, indent=2)
        elif format.lower() == "excel":
            df.to_excel(output_file, index=False)
        else:
            raise ValueError(f"不支持的格式: {format}")
        
        logger.info(f"数据已导出到 {output_file}, 共 {len(data)} 条记录")

# 使用示例
if __name__ == "__main__":
    db = DatabaseManager()
    
    # 获取统计信息
    stats = db.get_price_statistics(days=7)
    print("最近7天统计:", json.dumps(stats, ensure_ascii=False, indent=2))
    
    # 清理90天前的数据
    # cleanup_result = db.cleanup_old_data(90)
    # print("清理结果:", cleanup_result)
