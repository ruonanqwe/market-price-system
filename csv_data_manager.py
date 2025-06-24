#!/usr/bin/env python3
"""
CSV数据管理器 - 简单的数据存储和查询
保存数据到CSV文件，支持快速查询
"""

import os
import pandas as pd
import json
from datetime import datetime
from typing import Dict, List, Optional
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CSVDataManager:
    """CSV数据管理器"""
    
    def __init__(self, data_dir: str = "data"):
        self.data_dir = data_dir
        self.csv_file = os.path.join(data_dir, "market_prices.csv")
        self.ensure_data_dir()
    
    def ensure_data_dir(self):
        """确保数据目录存在"""
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
            logger.info(f"创建数据目录: {self.data_dir}")
    
    def save_data(self, data_list: List[Dict]) -> int:
        """保存数据到CSV文件"""
        if not data_list:
            logger.warning("没有数据需要保存")
            return 0
        
        try:
            # 转换为DataFrame
            df = pd.DataFrame(data_list)
            
            # 添加保存时间戳
            df['保存时间'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # 如果CSV文件已存在，追加数据
            if os.path.exists(self.csv_file):
                # 读取现有数据
                existing_df = pd.read_csv(self.csv_file, encoding='utf-8-sig')
                
                # 合并数据，去重
                combined_df = pd.concat([existing_df, df], ignore_index=True)
                
                # 根据关键字段去重（市场名称、品种名称、交易日期）
                if all(col in combined_df.columns for col in ['市场名称', '品种名称', '交易日期']):
                    combined_df = combined_df.drop_duplicates(
                        subset=['市场名称', '品种名称', '交易日期'], 
                        keep='last'
                    )
                
                df = combined_df
            
            # 保存到CSV
            df.to_csv(self.csv_file, index=False, encoding='utf-8-sig')
            
            logger.info(f"成功保存 {len(data_list)} 条数据到 {self.csv_file}")
            logger.info(f"CSV文件总记录数: {len(df)}")
            
            return len(data_list)
            
        except Exception as e:
            logger.error(f"保存数据到CSV失败: {e}")
            return 0
    
    def load_data(self) -> pd.DataFrame:
        """从CSV文件加载数据"""
        try:
            if not os.path.exists(self.csv_file):
                logger.warning(f"CSV文件不存在: {self.csv_file}")
                return pd.DataFrame()
            
            df = pd.read_csv(self.csv_file, encoding='utf-8-sig')
            logger.info(f"从CSV加载了 {len(df)} 条记录")
            return df
            
        except Exception as e:
            logger.error(f"从CSV加载数据失败: {e}")
            return pd.DataFrame()
    
    def search_data(self, filters: Dict = None, limit: int = 100) -> List[Dict]:
        """搜索数据"""
        df = self.load_data()
        
        if df.empty:
            return []
        
        # 应用过滤条件
        if filters:
            for key, value in filters.items():
                if value and key in df.columns:
                    # 支持模糊搜索
                    df = df[df[key].astype(str).str.contains(str(value), case=False, na=False)]
        
        # 限制返回数量
        if limit > 0:
            df = df.head(limit)
        
        # 转换为字典列表
        return df.to_dict('records')
    
    def get_provinces(self) -> List[str]:
        """获取所有省份列表"""
        df = self.load_data()
        
        if df.empty or '省份' not in df.columns:
            return []
        
        provinces = df['省份'].dropna().unique().tolist()
        return sorted(provinces)
    
    def get_varieties(self, province: str = None) -> List[str]:
        """获取品种列表"""
        df = self.load_data()
        
        if df.empty or '品种名称' not in df.columns:
            return []
        
        # 如果指定省份，先过滤
        if province and '省份' in df.columns:
            df = df[df['省份'].str.contains(province, case=False, na=False)]
        
        varieties = df['品种名称'].dropna().unique().tolist()
        return sorted(varieties)
    
    def get_markets(self, province: str = None) -> List[str]:
        """获取市场列表"""
        df = self.load_data()
        
        if df.empty or '市场名称' not in df.columns:
            return []
        
        # 如果指定省份，先过滤
        if province and '省份' in df.columns:
            df = df[df['省份'].str.contains(province, case=False, na=False)]
        
        markets = df['市场名称'].dropna().unique().tolist()
        return sorted(markets)
    
    def get_price_data(self, province: str = None, variety: str = None, 
                      market: str = None, limit: int = 100) -> List[Dict]:
        """获取价格数据"""
        filters = {}
        
        if province:
            filters['省份'] = province
        if variety:
            filters['品种名称'] = variety
        if market:
            filters['市场名称'] = market
        
        return self.search_data(filters, limit)
    
    def get_statistics(self) -> Dict:
        """获取数据统计信息"""
        df = self.load_data()
        
        if df.empty:
            return {
                "总记录数": 0,
                "省份数量": 0,
                "品种数量": 0,
                "市场数量": 0,
                "最新更新时间": None
            }
        
        stats = {
            "总记录数": len(df),
            "省份数量": df['省份'].nunique() if '省份' in df.columns else 0,
            "品种数量": df['品种名称'].nunique() if '品种名称' in df.columns else 0,
            "市场数量": df['市场名称'].nunique() if '市场名称' in df.columns else 0,
        }
        
        # 获取最新更新时间
        if '保存时间' in df.columns:
            stats["最新更新时间"] = df['保存时间'].max()
        elif '爬取时间' in df.columns:
            stats["最新更新时间"] = df['爬取时间'].max()
        else:
            stats["最新更新时间"] = None
        
        return stats
    
    def export_data(self, output_file: str, filters: Dict = None, format: str = "csv"):
        """导出数据"""
        data = self.search_data(filters, limit=0)  # 不限制数量
        
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
    
    def cleanup_old_data(self, days: int = 30):
        """清理旧数据"""
        df = self.load_data()
        
        if df.empty or '交易日期' not in df.columns:
            logger.warning("没有日期字段，无法清理旧数据")
            return
        
        try:
            # 转换日期格式
            df['交易日期'] = pd.to_datetime(df['交易日期'])
            
            # 计算截止日期
            cutoff_date = pd.Timestamp.now() - pd.Timedelta(days=days)
            
            # 过滤数据
            old_count = len(df)
            df = df[df['交易日期'] >= cutoff_date]
            new_count = len(df)
            
            # 保存清理后的数据
            df.to_csv(self.csv_file, index=False, encoding='utf-8-sig')
            
            logger.info(f"清理完成: 删除了 {old_count - new_count} 条旧数据")
            
        except Exception as e:
            logger.error(f"清理旧数据失败: {e}")

# 全局CSV数据管理器实例
csv_manager = CSVDataManager()

def get_csv_manager():
    """获取CSV数据管理器实例"""
    return csv_manager
