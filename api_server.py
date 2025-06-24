#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
农产品市场价格API服务
提供实时市场价格查询、地理位置就近推荐等功能
"""

from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import sqlite3
import json
import os
import logging
from datetime import datetime, timedelta
import requests
import asyncio
from contextlib import asynccontextmanager
import uvicorn
from market_crawler import MarketCrawler
import threading
import time

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('api_server.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 数据模型
class MarketPrice(BaseModel):
    market_id: str
    market_name: str
    variety_name: str
    min_price: float
    avg_price: float
    max_price: float
    unit: str
    trade_date: str
    province: str
    area: str
    crawl_time: str

class LocationRequest(BaseModel):
    latitude: float
    longitude: float
    radius: Optional[int] = 50  # 搜索半径，单位：公里

class PriceQuery(BaseModel):
    province: Optional[str] = None
    market_name: Optional[str] = None
    variety_name: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    limit: Optional[int] = 100

# 数据库管理类
class DatabaseManager:
    def __init__(self, db_path: str = "market_data.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """初始化数据库"""
        conn = sqlite3.connect(self.db_path)
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
                UNIQUE(market_id, variety_id, trade_date)
            )
        ''')
        
        # 创建索引
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_province ON market_prices(province)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_market_name ON market_prices(market_name)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_variety_name ON market_prices(variety_name)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_trade_date ON market_prices(trade_date)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_crawl_time ON market_prices(crawl_time)')
        
        conn.commit()
        conn.close()
        logger.info("数据库初始化完成")
    
    def insert_market_data(self, data_list: List[Dict]):
        """批量插入市场数据"""
        if not data_list:
            return
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            for data in data_list:
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
                    data.get('最低价', 0),
                    data.get('平均价', 0),
                    data.get('最高价', 0),
                    data.get('计量单位', ''),
                    data.get('交易日期', ''),
                    data.get('交易量', 0),
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
            
            conn.commit()
            logger.info(f"成功插入 {len(data_list)} 条数据")
            
        except Exception as e:
            conn.rollback()
            logger.error(f"插入数据失败: {str(e)}")
            raise
        finally:
            conn.close()
    
    def query_prices(self, query: PriceQuery) -> List[Dict]:
        """查询价格数据"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 构建查询条件
        conditions = []
        params = []
        
        if query.province:
            conditions.append("province LIKE ?")
            params.append(f"%{query.province}%")
        
        if query.market_name:
            conditions.append("market_name LIKE ?")
            params.append(f"%{query.market_name}%")
        
        if query.variety_name:
            conditions.append("variety_name LIKE ?")
            params.append(f"%{query.variety_name}%")
        
        if query.start_date:
            conditions.append("trade_date >= ?")
            params.append(query.start_date)
        
        if query.end_date:
            conditions.append("trade_date <= ?")
            params.append(query.end_date)
        
        where_clause = " AND ".join(conditions) if conditions else "1=1"
        
        sql = f'''
            SELECT * FROM market_prices 
            WHERE {where_clause}
            ORDER BY trade_date DESC, crawl_time DESC
            LIMIT ?
        '''
        params.append(query.limit)
        
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
        finally:
            conn.close()

# 全局变量
db_manager = DatabaseManager()
crawler = MarketCrawler()
crawler_thread = None
crawler_running = False

# 地理位置服务
class LocationService:
    @staticmethod
    def get_nearby_markets(lat: float, lon: float, radius: int = 50) -> List[Dict]:
        """根据地理位置获取附近的市场"""
        # 这里使用简单的距离计算，实际应用中可以使用更精确的地理计算
        # 暂时返回所有市场数据，按省份优先级排序
        query = PriceQuery(limit=50)
        all_markets = db_manager.query_prices(query)
        
        # 简单的地理位置匹配逻辑（可以根据需要改进）
        # 这里按省份进行粗略的地理位置匹配
        location_priority = LocationService._get_location_priority(lat, lon)
        
        # 按优先级排序
        sorted_markets = sorted(all_markets, 
                              key=lambda x: location_priority.get(x.get('province', ''), 999))
        
        return sorted_markets[:20]  # 返回前20个最相关的市场
    
    @staticmethod
    def _get_location_priority(lat: float, lon: float) -> Dict[str, int]:
        """根据经纬度返回省份优先级"""
        # 简化的省份地理位置优先级映射
        # 实际应用中应该使用更精确的地理计算
        priority_map = {
            "北京市": 1, "天津市": 2, "河北省": 3,
            "上海市": 4, "江苏省": 5, "浙江省": 6,
            "广东省": 7, "深圳市": 8, "山东省": 9,
            # ... 可以根据实际需要扩展
        }
        
        # 根据经纬度范围调整优先级
        if 39 <= lat <= 41 and 115 <= lon <= 118:  # 北京周边
            priority_map.update({"北京市": 1, "天津市": 2, "河北省": 3})
        elif 30 <= lat <= 32 and 120 <= lon <= 122:  # 上海周边
            priority_map.update({"上海市": 1, "江苏省": 2, "浙江省": 3})
        elif 22 <= lat <= 24 and 112 <= lon <= 115:  # 广东周边
            priority_map.update({"广东省": 1, "广西壮族自治区": 2, "海南省": 3})
        
        return priority_map

# 数据爬取服务
def run_crawler():
    """后台运行数据爬取"""
    global crawler_running
    crawler_running = True
    
    while crawler_running:
        try:
            logger.info("开始爬取市场数据...")
            
            # 获取所有省份的数据
            all_data = []
            for province in crawler.provinces:
                try:
                    province_code = province["code"]
                    province_name = province["name"]
                    
                    # 获取该省份的市场数据
                    url = f"{crawler.base_url}/priceQuotationController/getTodayMarketByProvinceCode"
                    params = {"code": province_code}
                    
                    response = requests.post(
                        url, 
                        headers=crawler.headers, 
                        params=params,
                        verify=False,
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        data = response.json()
                        if data.get("code") == 200 and "content" in data:
                            markets = data["content"]
                            
                            for market in markets:
                                market_id = market.get("marketId")
                                if market_id:
                                    details = crawler.fetch_market_details(market_id)
                                    if details:
                                        # 添加省份信息
                                        for detail in details:
                                            detail["省份"] = province_name
                                            detail["省份代码"] = province_code
                                        all_data.extend(details)
                                    
                                    time.sleep(1)  # 避免请求过快
                    
                    time.sleep(2)  # 省份间隔
                    
                except Exception as e:
                    logger.error(f"爬取 {province_name} 数据失败: {str(e)}")
                    continue
            
            # 保存到数据库
            if all_data:
                db_manager.insert_market_data(all_data)
                logger.info(f"本轮爬取完成，共获取 {len(all_data)} 条数据")
            
            # 等待30分钟后进行下一轮爬取
            time.sleep(30 * 60)
            
        except Exception as e:
            logger.error(f"爬取过程出错: {str(e)}")
            time.sleep(60)  # 出错后等待1分钟再重试

# FastAPI应用
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时执行
    global crawler_thread
    crawler_thread = threading.Thread(target=run_crawler, daemon=True)
    crawler_thread.start()
    logger.info("API服务启动，后台数据爬取已开始")
    
    yield
    
    # 关闭时执行
    global crawler_running
    crawler_running = False
    logger.info("API服务关闭")

app = FastAPI(
    title="农产品市场价格API",
    description="提供全国农产品市场实时价格查询服务",
    version="1.0.0",
    lifespan=lifespan
)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """API根路径"""
    return {
        "message": "农产品市场价格API服务",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running"
    }

@app.get("/api/health")
async def health_check():
    """健康检查"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "crawler_running": crawler_running
    }

@app.post("/api/prices/query")
async def query_prices(query: PriceQuery):
    """查询市场价格"""
    try:
        results = db_manager.query_prices(query)
        return {
            "success": True,
            "count": len(results),
            "data": results
        }
    except Exception as e:
        logger.error(f"查询价格失败: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/prices/nearby")
async def get_nearby_prices(location: LocationRequest):
    """根据地理位置获取附近市场价格"""
    try:
        results = LocationService.get_nearby_markets(
            location.latitude, 
            location.longitude, 
            location.radius
        )
        return {
            "success": True,
            "location": {
                "latitude": location.latitude,
                "longitude": location.longitude,
                "radius": location.radius
            },
            "count": len(results),
            "data": results
        }
    except Exception as e:
        logger.error(f"获取附近价格失败: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/provinces")
async def get_provinces():
    """获取所有省份列表"""
    return {
        "success": True,
        "data": crawler.provinces
    }

@app.get("/api/varieties")
async def get_varieties(province: Optional[str] = None):
    """获取品种列表"""
    try:
        conn = sqlite3.connect(db_manager.db_path)
        cursor = conn.cursor()
        
        if province:
            cursor.execute(
                "SELECT DISTINCT variety_name FROM market_prices WHERE province LIKE ? ORDER BY variety_name",
                (f"%{province}%",)
            )
        else:
            cursor.execute("SELECT DISTINCT variety_name FROM market_prices ORDER BY variety_name")
        
        varieties = [row[0] for row in cursor.fetchall()]
        conn.close()
        
        return {
            "success": True,
            "count": len(varieties),
            "data": varieties
        }
    except Exception as e:
        logger.error(f"获取品种列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/markets")
async def get_markets(province: Optional[str] = None):
    """获取市场列表"""
    try:
        conn = sqlite3.connect(db_manager.db_path)
        cursor = conn.cursor()
        
        if province:
            cursor.execute(
                "SELECT DISTINCT market_name, province FROM market_prices WHERE province LIKE ? ORDER BY market_name",
                (f"%{province}%",)
            )
        else:
            cursor.execute("SELECT DISTINCT market_name, province FROM market_prices ORDER BY province, market_name")
        
        markets = [{"name": row[0], "province": row[1]} for row in cursor.fetchall()]
        conn.close()
        
        return {
            "success": True,
            "count": len(markets),
            "data": markets
        }
    except Exception as e:
        logger.error(f"获取市场列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=1
    )
