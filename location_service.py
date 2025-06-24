#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
地理位置服务
提供基于地理位置的市场推荐和价格比较功能
"""

import math
import requests
import logging
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
import json
import sqlite3
from datetime import datetime

logger = logging.getLogger(__name__)

@dataclass
class Location:
    latitude: float
    longitude: float
    address: str = ""
    city: str = ""
    province: str = ""

@dataclass
class MarketLocation:
    market_name: str
    province: str
    city: str
    latitude: float
    longitude: float
    distance: float = 0.0

class LocationService:
    def __init__(self, db_path: str = "market_data.db"):
        self.db_path = db_path
        # 主要城市坐标数据（可以扩展）
        self.city_coordinates = {
            # 直辖市
            "北京市": {"lat": 39.9042, "lon": 116.4074, "province": "北京市"},
            "上海市": {"lat": 31.2304, "lon": 121.4737, "province": "上海市"},
            "天津市": {"lat": 39.3434, "lon": 117.3616, "province": "天津市"},
            "重庆市": {"lat": 29.5647, "lon": 106.5507, "province": "重庆市"},
            
            # 省会城市
            "石家庄市": {"lat": 38.0428, "lon": 114.5149, "province": "河北省"},
            "太原市": {"lat": 37.8706, "lon": 112.5489, "province": "山西省"},
            "呼和浩特市": {"lat": 40.8414, "lon": 111.7519, "province": "内蒙古自治区"},
            "沈阳市": {"lat": 41.8057, "lon": 123.4315, "province": "辽宁省"},
            "长春市": {"lat": 43.8171, "lon": 125.3235, "province": "吉林省"},
            "哈尔滨市": {"lat": 45.8038, "lon": 126.5349, "province": "黑龙江省"},
            "南京市": {"lat": 32.0603, "lon": 118.7969, "province": "江苏省"},
            "杭州市": {"lat": 30.2741, "lon": 120.1551, "province": "浙江省"},
            "合肥市": {"lat": 31.8206, "lon": 117.2272, "province": "安徽省"},
            "福州市": {"lat": 26.0745, "lon": 119.2965, "province": "福建省"},
            "南昌市": {"lat": 28.6820, "lon": 115.8581, "province": "江西省"},
            "济南市": {"lat": 36.6512, "lon": 117.1201, "province": "山东省"},
            "郑州市": {"lat": 34.7466, "lon": 113.6254, "province": "河南省"},
            "武汉市": {"lat": 30.5928, "lon": 114.3055, "province": "湖北省"},
            "长沙市": {"lat": 28.2282, "lon": 112.9388, "province": "湖南省"},
            "广州市": {"lat": 23.1291, "lon": 113.2644, "province": "广东省"},
            "南宁市": {"lat": 22.8170, "lon": 108.3669, "province": "广西壮族自治区"},
            "海口市": {"lat": 20.0444, "lon": 110.1989, "province": "海南省"},
            "成都市": {"lat": 30.5728, "lon": 104.0668, "province": "四川省"},
            "贵阳市": {"lat": 26.6470, "lon": 106.6302, "province": "贵州省"},
            "昆明市": {"lat": 25.0389, "lon": 102.7183, "province": "云南省"},
            "拉萨市": {"lat": 29.6625, "lon": 91.1146, "province": "西藏自治区"},
            "西安市": {"lat": 34.3416, "lon": 108.9398, "province": "陕西省"},
            "兰州市": {"lat": 36.0611, "lon": 103.8343, "province": "甘肃省"},
            "西宁市": {"lat": 36.6171, "lon": 101.7782, "province": "青海省"},
            "银川市": {"lat": 38.4872, "lon": 106.2309, "province": "宁夏回族自治区"},
            "乌鲁木齐市": {"lat": 43.8256, "lon": 87.6168, "province": "新疆维吾尔自治区"},
            
            # 重要城市
            "深圳市": {"lat": 22.5431, "lon": 114.0579, "province": "广东省"},
            "青岛市": {"lat": 36.0671, "lon": 120.3826, "province": "山东省"},
            "大连市": {"lat": 38.9140, "lon": 121.6147, "province": "辽宁省"},
            "宁波市": {"lat": 29.8683, "lon": 121.5440, "province": "浙江省"},
            "厦门市": {"lat": 24.4798, "lon": 118.0894, "province": "福建省"},
            "苏州市": {"lat": 31.2989, "lon": 120.5853, "province": "江苏省"},
            "无锡市": {"lat": 31.4912, "lon": 120.3119, "province": "江苏省"},
        }
    
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        使用Haversine公式计算两点间距离（公里）
        """
        # 转换为弧度
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        
        # Haversine公式
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        # 地球半径（公里）
        r = 6371
        
        return c * r
    
    def get_location_from_coordinates(self, lat: float, lon: float) -> Location:
        """
        根据经纬度获取地址信息（使用高德地图API）
        """
        try:
            # 这里可以集成高德地图、百度地图等API
            # 暂时使用简单的城市匹配
            closest_city = self._find_closest_city(lat, lon)
            
            return Location(
                latitude=lat,
                longitude=lon,
                city=closest_city["name"],
                province=closest_city["province"],
                address=f"{closest_city['province']}{closest_city['name']}"
            )
        except Exception as e:
            logger.error(f"获取地址信息失败: {str(e)}")
            return Location(latitude=lat, longitude=lon)
    
    def _find_closest_city(self, lat: float, lon: float) -> Dict:
        """找到最近的城市"""
        min_distance = float('inf')
        closest_city = {"name": "未知", "province": "未知"}
        
        for city_name, coords in self.city_coordinates.items():
            distance = self.calculate_distance(lat, lon, coords["lat"], coords["lon"])
            if distance < min_distance:
                min_distance = distance
                closest_city = {
                    "name": city_name,
                    "province": coords["province"],
                    "distance": distance
                }
        
        return closest_city
    
    def get_nearby_markets(self, lat: float, lon: float, radius: int = 100) -> List[Dict]:
        """
        获取附近的市场及其价格信息
        """
        try:
            # 获取用户位置信息
            user_location = self.get_location_from_coordinates(lat, lon)
            
            # 从数据库获取市场数据
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # 获取最近的市场数据
            cursor.execute('''
                SELECT DISTINCT 
                    market_name, province, area_name,
                    variety_name, avg_price, min_price, max_price,
                    unit, trade_date, crawl_time
                FROM market_prices 
                WHERE trade_date >= date('now', '-7 days')
                ORDER BY crawl_time DESC
            ''')
            
            results = cursor.fetchall()
            conn.close()
            
            # 计算距离并排序
            market_data = []
            for row in results:
                market_name, province, area_name, variety_name, avg_price, min_price, max_price, unit, trade_date, crawl_time = row
                
                # 获取市场位置
                market_coords = self._get_market_coordinates(province, area_name or province)
                if market_coords:
                    distance = self.calculate_distance(
                        lat, lon, 
                        market_coords["lat"], market_coords["lon"]
                    )
                    
                    if distance <= radius:
                        market_data.append({
                            "market_name": market_name,
                            "province": province,
                            "area": area_name,
                            "variety_name": variety_name,
                            "avg_price": avg_price,
                            "min_price": min_price,
                            "max_price": max_price,
                            "unit": unit,
                            "trade_date": trade_date,
                            "distance": round(distance, 2),
                            "location": {
                                "latitude": market_coords["lat"],
                                "longitude": market_coords["lon"]
                            }
                        })
            
            # 按距离排序
            market_data.sort(key=lambda x: x["distance"])
            
            return market_data[:50]  # 返回最近的50个市场
            
        except Exception as e:
            logger.error(f"获取附近市场失败: {str(e)}")
            return []
    
    def _get_market_coordinates(self, province: str, area: str) -> Optional[Dict]:
        """获取市场坐标"""
        # 首先尝试匹配具体城市
        for city_name, coords in self.city_coordinates.items():
            if area and area in city_name:
                return coords
            if province and province in coords["province"]:
                return coords
        
        # 如果没有找到，返回省会城市坐标
        for city_name, coords in self.city_coordinates.items():
            if coords["province"] == province:
                return coords
        
        return None
    
    def compare_prices_by_location(self, variety: str, lat: float, lon: float, radius: int = 200) -> Dict:
        """
        比较指定品种在不同地区的价格
        """
        try:
            nearby_markets = self.get_nearby_markets(lat, lon, radius)
            
            # 筛选指定品种
            variety_data = [m for m in nearby_markets if variety in m["variety_name"]]
            
            if not variety_data:
                return {
                    "variety": variety,
                    "message": f"在{radius}公里范围内未找到{variety}的价格信息"
                }
            
            # 统计分析
            prices = [m["avg_price"] for m in variety_data if m["avg_price"] > 0]
            
            if not prices:
                return {
                    "variety": variety,
                    "message": f"找到{len(variety_data)}个市场，但价格信息不完整"
                }
            
            # 价格统计
            min_price_market = min(variety_data, key=lambda x: x["avg_price"] if x["avg_price"] > 0 else float('inf'))
            max_price_market = max(variety_data, key=lambda x: x["avg_price"])
            
            return {
                "variety": variety,
                "search_radius": radius,
                "total_markets": len(variety_data),
                "price_range": {
                    "min": min(prices),
                    "max": max(prices),
                    "avg": round(sum(prices) / len(prices), 2)
                },
                "cheapest_market": {
                    "name": min_price_market["market_name"],
                    "province": min_price_market["province"],
                    "price": min_price_market["avg_price"],
                    "distance": min_price_market["distance"],
                    "unit": min_price_market["unit"]
                },
                "most_expensive_market": {
                    "name": max_price_market["market_name"],
                    "province": max_price_market["province"],
                    "price": max_price_market["avg_price"],
                    "distance": max_price_market["distance"],
                    "unit": max_price_market["unit"]
                },
                "all_markets": variety_data
            }
            
        except Exception as e:
            logger.error(f"价格比较失败: {str(e)}")
            return {"error": str(e)}
    
    def get_price_trend_by_location(self, variety: str, province: str, days: int = 30) -> Dict:
        """
        获取指定地区指定品种的价格趋势
        """
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT trade_date, AVG(avg_price) as avg_price, COUNT(*) as market_count
                FROM market_prices 
                WHERE variety_name LIKE ? AND province LIKE ?
                AND trade_date >= date('now', '-{} days')
                AND avg_price > 0
                GROUP BY trade_date
                ORDER BY trade_date
            '''.format(days), (f"%{variety}%", f"%{province}%"))
            
            results = cursor.fetchall()
            conn.close()
            
            if not results:
                return {
                    "variety": variety,
                    "province": province,
                    "message": "未找到价格趋势数据"
                }
            
            trend_data = []
            for row in results:
                trade_date, avg_price, market_count = row
                trend_data.append({
                    "date": trade_date,
                    "avg_price": round(avg_price, 2),
                    "market_count": market_count
                })
            
            # 计算趋势
            if len(trend_data) >= 2:
                first_price = trend_data[0]["avg_price"]
                last_price = trend_data[-1]["avg_price"]
                trend = "上涨" if last_price > first_price else "下跌" if last_price < first_price else "平稳"
                change_rate = round(((last_price - first_price) / first_price) * 100, 2) if first_price > 0 else 0
            else:
                trend = "数据不足"
                change_rate = 0
            
            return {
                "variety": variety,
                "province": province,
                "period_days": days,
                "trend": trend,
                "change_rate": f"{change_rate}%",
                "data_points": len(trend_data),
                "price_data": trend_data
            }
            
        except Exception as e:
            logger.error(f"获取价格趋势失败: {str(e)}")
            return {"error": str(e)}

# 使用示例
if __name__ == "__main__":
    service = LocationService()
    
    # 测试北京地区的市场查询
    beijing_lat, beijing_lon = 39.9042, 116.4074
    nearby = service.get_nearby_markets(beijing_lat, beijing_lon, 100)
    print(f"北京附近100公里内的市场数量: {len(nearby)}")
    
    # 测试价格比较
    if nearby:
        variety = "白萝卜"  # 示例品种
        comparison = service.compare_prices_by_location(variety, beijing_lat, beijing_lon, 200)
        print(f"{variety}价格比较结果:", json.dumps(comparison, ensure_ascii=False, indent=2))
