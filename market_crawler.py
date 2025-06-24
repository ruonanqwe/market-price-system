# **************************************************************************
# *                                                                          *
# *                        农产品市场数据爬虫                                 *
# *                                                                          *
# *                          作者: xiaohai                                   *
# *                          版本: v1.0.0                                    *
# *                          日期: 2024-12-05                                *
# *                                                                          *
# *          功能:                                                           *
# *              - 支持选择性爬取指定省份数据                                 *
# *              - 支持CSV/JSON多种格式导出                                  *
# *              - 自动保存历史数据并去重                                    *
# *              - 支持断点续传和错误重试
# *                                                                          *
# *          注意:                                                           *
# *              - 由于数据来源的限制，部分数据可能无法获取                 *
# *              - 部分数据可能存在缺失或错误                                  *
# *              - 请确保在合法合规的前提下使用本程序                      *
# *                                                                          *
# *          运行:                                                           *
# *              - 命令行运行: python market_crawler.py                        *
# *              - 选择性运行: python market_crawler.py -p 广东省                *
# *                                                                          *
# *          导出:                                                           *
# *              - CSV格式: python market_crawler.py -p 广东省 -o data.csv     *
# *              - JSON格式: python market_crawler.py -p 广东省 -o data.json   *
# *             - Excel格式: python market_crawler.py -p 广东省 -o data.xlsx 
# *                                                                          *
# *          文件夹格式:                                                       *
# *              - market_crawler                                             *
# *                  - 20xxxxxx                                               *
# *                      - 市场1                                               *
# *                      - 市场2                                               *
# *                      -...                                                 *
# *                  - 20xxxxxx                                               *
# *                      - 市场1                                               *
# *                      - 市场2                                               *
# *                      -...                                                 *
# *                  -...                                                   *
# *                  - merged                                                 *
# *                      - all_data_2024xxxx.csv                               *
# *                      - all_data_2024xxxx.json                              *
#                    - summary                                                *
# *                      - summary_2024xxxx.csv                                *
# *                      - summary_2024xxxx.json                              *
# *                      - summary_2024xxxx.csv                              *
# *                      - summary_2024xxxx.json                              *
# *                      -...                                                  *
# *              - market_crawler_log.txt                                       *
#                - market_crawler.py                                          *
# *                                                                          *
# *          断点续传:                                                        *
# *              - 程序会自动保存历史数据，下次运行时会自动加载并去重            *
# *              - 若需要重新开始，请删除历史数据文件                          *
# *                                                                          *
# **************************************************************************

import pkg_resources
import sys
import argparse
import subprocess

def check_and_install_packages():
    """检查并安装所需的包"""
    required_packages = {
        'requests': 'requests',
        'pandas': 'pandas',
        'beautifulsoup4': 'bs4',
        'urllib3': 'urllib3',
        'openpyxl': 'openpyxl',  # Excel支持
        'lxml': 'lxml',          # XML解析器
        'chardet': 'chardet',    # 字符编码检测
        'tqdm': 'tqdm',          # 进度条
        'colorama': 'colorama'   # 控制台颜色
    }
    
    print("\n" + "="*50)
    print("检查并安装依赖包...")
    print("="*50)
    
    try:
        import colorama
        colorama.init()  # 初始化控制台颜色
        success_mark = colorama.Fore.GREEN + "✓" + colorama.Style.RESET_ALL
        error_mark = colorama.Fore.RED + "✗" + colorama.Style.RESET_ALL
    except ImportError:
        success_mark = "✓"
        error_mark = "✗"
    
    all_success = True

    # 👇 镜像源配置（可更换为其他源）
    mirror_url = "https://mirrors.aliyun.com/pypi/simple/"
    trusted_hosts = [
        "files.pythonhosted.org",
        "pypi.org",
        "mirrors.aliyun.com"
    ]

    for package, import_name in required_packages.items():
        try:
            pkg_resources.require(package)
            print(f"{success_mark} {package:15} 已安装")
        except (pkg_resources.DistributionNotFound, pkg_resources.VersionConflict):
            print(f"{error_mark} {package:15} 未安装，正在安装...")
            try:
                # 使用 pip 安装包，并指定镜像源和信任主机
                subprocess.check_call([
                    sys.executable,
                    "-m",
                    "pip",
                    "install",
                    "--disable-pip-version-check",  # 禁用pip版本检查
                    "--no-cache-dir",               # 禁用缓存
                    "-i", mirror_url,               # 指定镜像源
                    *[f"--trusted-host={host}" for host in trusted_hosts],  # 添加信任的主机
                    package
                ], stdout=subprocess.DEVNULL)
                print(f"{success_mark} {package:15} 安装成功")
            except subprocess.CalledProcessError as e:
                print(f"{error_mark} {package:15} 安装失败: {str(e)}")
                all_success = False
            except Exception as e:
                print(f"{error_mark} {package:15} 安装出错: {str(e)}")
                all_success = False
    
    print("\n依赖包检查" + ("全部完成" if all_success else "存在问题"))
    print("="*50 + "\n")
    
    if not all_success:
        print("某些依赖包安装失败，程序可能无法正常运行！")
        if input("是否继续运行？(y/n): ").lower() != 'y':
            sys.exit(1)
try:
    # 检查并安装依赖包
    check_and_install_packages()
    
    # 导入所需的包
    import requests
    import pandas as pd
    import logging
    import time
    from datetime import datetime, timedelta
    import os
    from typing import Dict, List
    from bs4 import BeautifulSoup
    import urllib3
    import json
    from tqdm import tqdm
    import chardet
    
    # 禁用SSL警告
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
except Exception as e:
    print(f"\n程序初始化失败: {str(e)}")
    sys.exit(1)

class MarketCrawler:
    def __init__(self):
        self.base_url = "https://pfsc.agri.cn/api"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Content-Type": "application/json;charset=UTF-8",
            "Origin": "https://pfsc.agri.cn",
            "Referer": "https://pfsc.agri.cn/",
            "Connection": "keep-alive",
            "sec-ch-ua": '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
            "sec-ch-ua-mobile": "?0",
            "sec-ch-ua-platform": "Windows",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin"
        }
        # 修改数据保存目录为相对路径
        script_dir = os.path.dirname(os.path.abspath(__file__))
        self.data_dir = os.path.join(script_dir, "market_data")
        os.makedirs(self.data_dir, exist_ok=True)
        
        # 省份代码列表
        self.provinces = [
            {"code": "110000", "name": "北京市"},
            {"code": "120000", "name": "天津市"},
            {"code": "130000", "name": "河北省"},
            {"code": "140000", "name": "山西省"},
            {"code": "150000", "name": "内蒙古自治区"},
            {"code": "210000", "name": "辽宁省"},
            {"code": "220000", "name": "吉林省"},
            {"code": "230000", "name": "黑龙江省"},
            {"code": "310000", "name": "上海市"},
            {"code": "320000", "name": "江苏省"},
            {"code": "330000", "name": "浙江省"},
            {"code": "340000", "name": "安徽省"},
            {"code": "350000", "name": "福建省"},
            {"code": "360000", "name": "江西省"},
            {"code": "370000", "name": "山东省"},
            {"code": "410000", "name": "河南省"},
            {"code": "420000", "name": "湖北省"},
            {"code": "430000", "name": "湖南省"},
            {"code": "440000", "name": "广东省"},
            {"code": "450000", "name": "广西壮族自治区"},
            {"code": "460000", "name": "海南省"},
            {"code": "500000", "name": "重庆市"},
            {"code": "510000", "name": "四川省"},
            {"code": "520000", "name": "贵州省"},
            {"code": "530000", "name": "云南省"},
            {"code": "540000", "name": "西藏自治区"},
            {"code": "610000", "name": "陕西省"},
            {"code": "620000", "name": "甘肃省"},
            {"code": "630000", "name": "青海省"},
            {"code": "640000", "name": "宁夏回族自治区"},
            {"code": "650000", "name": "新疆维吾尔自治区"}
        ]
        
        # 添加配置选项
        self.config = {
            "retry_times": 3,
            "retry_delay": 5,
            "export_format": "both",  # 可选: "csv", "json", "both"
        }
        
        self.setup_logging()

    def setup_logging(self):
        # 确保日志文件保存在脚本所在目
        script_dir = os.path.dirname(os.path.abspath(__file__))
        log_file = os.path.join(script_dir, 'market_crawler.log')
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging

    def fetch_provinces(self) -> List[Dict]:
        """获取所有省份信息"""
        try:
            url = f"{self.base_url}/priceQuotationController/getProvinceList"
            response = requests.get(
                url,
                headers=self.headers,
                verify=False,
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            if data.get("code") == 200:
                return data.get("content", [])
            return []
        except Exception as e:
            self.logger.error(f"获取省份列表失败: {str(e)}")
            return []

    def get_export_config(self):
        """获取导出配置"""
        print("\n=== 导出配置 ===")
        print("1. 仅导出CSV")
        print("2. 仅导出JSON")
        print("3. 两种格式都导出(认)")
        
        while True:
            choice = input("请选择导出格式 [1-3]: ").strip()
            if not choice:  # 默认两种都导出
                return
            
            try:
                choice = int(choice)
                if choice == 1:
                    self.config["export_format"] = "csv"
                    break
                elif choice == 2:
                    self.config["export_format"] = "json"
                    break
                elif choice == 3:
                    self.config["export_format"] = "both"
                    break
                else:
                    print("请输入1-3之间的数字！")
            except ValueError:
                print("请输入有效的数字！")
        
        print(f"\n已选择: {self.config['export_format'].upper()}")

    def check_price_changed(self, market_name: str, new_data: List[Dict]) -> bool:
        """检查价格是否有变化"""
        try:
            market_dir = os.path.join(self.data_dir, market_name)
            if not os.path.exists(market_dir):
                return True  # 目录不存在，说明是新市场
            
            # 获取最新的CSV文件
            csv_files = [f for f in os.listdir(market_dir) if f.endswith('.csv') and not f.endswith('_all.csv')]
            if not csv_files:
                return True  # 没有历史文件，需要保存
            
            latest_file = max(csv_files, key=lambda x: os.path.getctime(os.path.join(market_dir, x)))
            latest_df = pd.read_csv(os.path.join(market_dir, latest_file))
            
            # 确保数据格式一致
            latest_df['交易日期'] = pd.to_datetime(latest_df['交易日期']).dt.date
            new_df = pd.DataFrame(new_data)
            new_df['交易日期'] = pd.to_datetime(new_df['交易日期']).dt.date
            
            # 只比较今天的数据
            today = datetime.now().date()
            latest_today = latest_df[latest_df['交易日期'] == today]
            new_today = new_df[new_df['交易日期'] == today]
            
            if len(latest_today) == 0 or len(new_today) == 0:
                return True  # 任一方没有今天的数据，需要保存
            
            # 比较关键字段是否有变化
            price_columns = ['最低价', '平均价', '最高价']
            for col in price_columns:
                if not (latest_today[col] == new_today[col]).all():
                    return True  # 价格有变化
            
            self.logger.info(f"市场 {market_name} 价格无变化，跳过保存")
            return False
            
        except Exception as e:
            self.logger.error(f"检查价格变化失败: {str(e)}")
            return True  # 出错时保险起见还是保存数据

    def save_market_data(self, market_name: str, data: List[Dict]):
        """保存单个市场的数据"""
        try:
            if not data:
                return
            
            # 检查价格是否有变化
            if not self.check_price_changed(market_name, data):
                return
            
            # 生成文件名和时间戳
            timestamp = datetime.now()
            date_str = timestamp.strftime("%Y%m%d")
            
            # 为数据添加爬取时间
            for item in data:
                item['爬取时间'] = timestamp.strftime("%Y-%m-%d %H:%M:%S")
            
            # 创建日期目录和市场目录
            date_dir = os.path.join(self.data_dir, date_str)
            safe_market_name = "".join(x for x in market_name if x.isalnum() or x in ['-', '_'])
            market_dir = os.path.join(date_dir, safe_market_name)
            os.makedirs(market_dir, exist_ok=True)
            
            # 转换为DataFrame
            new_df = pd.DataFrame(data)
            
            # 根据配置保存数据
            if self.config["export_format"] in ["json", "both"]:
                json_file = os.path.join(market_dir, f"{safe_market_name}.json")
                if os.path.exists(json_file):
                    # 如果文件存在，读取并合并数据
                    try:
                        with open(json_file, 'r', encoding='utf-8') as f:
                            existing_data = json.load(f)
                            if isinstance(existing_data, list):
                                # 合并数据并去重
                                all_data = existing_data + data
                                # 使用字典去重，保留最新的数据
                                unique_data = {}
                                for item in all_data:
                                    key = (item['市场ID'], item['品种ID'], item['交易日期'])
                                    unique_data[key] = item
                                data = list(unique_data.values())
                    except Exception as e:
                        self.logger.error(f"读取JSON文件失败: {str(e)}")
                
                # 保存合并后的数据
                with open(json_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                self.logger.info(f"JSON数据已更新到 {json_file}")
            
            if self.config["export_format"] in ["csv", "both"]:
                csv_file = os.path.join(market_dir, f"{safe_market_name}.csv")
                if os.path.exists(csv_file):
                    # 如果文件存在，读取并合并数据
                    try:
                        existing_df = pd.read_csv(csv_file)
                        new_df = pd.concat([existing_df, new_df], ignore_index=True)
                        # 去重，保留最新的数据
                        new_df = new_df.sort_values('爬取时间').drop_duplicates(
                            subset=['市场ID', '品种ID', '交易日期'], 
                            keep='last'
                        )
                    except Exception as e:
                        self.logger.error(f"读取CSV文件失败: {str(e)}")
                
                # 保存合并后的数据
                new_df = new_df.sort_values(['交易日期', '品种名称'])
                new_df.to_csv(csv_file, index=False, encoding='utf-8-sig')
                self.logger.info(f"CSV数据已更新到 {csv_file}")
                
                # 更新汇总文件
                summary_file = os.path.join(market_dir, f"{safe_market_name}_summary.csv")
                try:
                    if os.path.exists(summary_file):
                        summary_df = pd.read_csv(summary_file)
                        summary_df = pd.concat([summary_df, new_df], ignore_index=True)
                    else:
                        summary_df = new_df.copy()
                    
                    # 去重并排序
                    summary_df = summary_df.sort_values('爬取时间').drop_duplicates(
                        subset=['市场ID', '品种ID', '交易日期'], 
                        keep='last'
                    )
                    summary_df = summary_df.sort_values(['交易日期', '品种名称'])
                    summary_df.to_csv(summary_file, index=False, encoding='utf-8-sig')
                    self.logger.info(f"汇总数据已更新到 {summary_file}")
                    
                except Exception as e:
                    self.logger.error(f"更新汇总文件失败: {str(e)}")
            
        except Exception as e:
            self.logger.error(f"保存市场 {market_name} 数据失败: {str(e)}")
            raise

    def fetch_market_details(self, market_id: str) -> List[Dict]:
        """获取单个市场的详细信息"""
        max_retries = 3
        retry_delay = 5
        all_items = []
        page_num = 1
        timestamp = datetime.now()
        
        while True:
            for retry in range(max_retries):
                try:
                    url = f"{self.base_url}/priceQuotationController/pageList"
                    
                    # 构建请求体
                    payload = {
                        "marketId": market_id,
                        "pageNum": page_num,
                        "pageSize": 40,
                        "order": "desc",
                        "key": "",
                        "varietyTypeId": "",
                        "varietyId": "",
                        "startDate": (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d"),
                        "endDate": datetime.now().strftime("%Y-%m-%d")
                    }
                    
                    # 发送请求
                    session = requests.Session()
                    response = session.post(
                        url,
                        headers=self.headers,
                        json=payload,  # 使用json参数而不是data
                        verify=False,
                        timeout=30
                    )
                    
                    # 检查响应状态
                    if response.status_code != 200:
                        raise requests.exceptions.RequestException(f"HTTP {response.status_code}")
                    
                    # 检查响应内容
                    if not response.content:
                        raise ValueError("Empty response received")
                    
                    data = response.json()
                    
                    if data.get("code") == 200:
                        content = data.get("content", {})
                        items = content.get("list", [])
                        total = content.get("total", 0)
                        pages = content.get("pages", 1)
                        
                        if items:
                            processed_items = []
                            for item in items:
                                try:
                                    # 从返回的数据中获取省份信息
                                    province_name = str(item.get("provinceName", ""))
                                    province_code = str(item.get("provinceCode", ""))
                                    
                                    processed_item = {
                                        # 市场基本信息
                                        "市场ID": str(market_id),
                                        "市场代码": str(item.get("marketCode", "")),
                                        "市场名称": str(item.get("marketName", "")),
                                        "市场类型": str(item.get("marketType", "")),
                                        
                                        # 品种信息
                                        "品种ID": str(item.get("varietyId", "")),
                                        "品种名称": str(item.get("varietyName", "")),
                                        
                                        # 价格信息
                                        "最低价": float(item.get("minimumPrice", 0) or 0),
                                        "平均价": float(item.get("middlePrice", 0) or 0),
                                        "最高价": float(item.get("highestPrice", 0) or 0),
                                        "计量单位": str(item.get("meteringUnit", "")),
                                        
                                        # 交易信息
                                        "交易日期": str(item.get("reportTime", "")),  # 使用reportTime作为交易日期
                                        "交易量": float(item.get("tradingVolume", 0) or 0),
                                        
                                        # 地理信息
                                        "产地": str(item.get("producePlace", "")),
                                        "销售地": str(item.get("salePlace", "")),
                                        "省份": province_name,
                                        "省份代码": province_code,
                                        "地区名称": str(item.get("areaName", "")),  # 添加地区信息
                                        "地区代码": str(item.get("areaCode", "")),
                                        
                                        # 其他信息
                                        "品种类型": str(item.get("varietyTypeName", "")),
                                        "品种类型ID": str(item.get("varietyTypeId", "")),
                                        "入库时间": str(item.get("inStorageTime", "")),
                                        "爬取时间": timestamp.strftime("%Y-%m-%d %H:%M:%S")
                                    }
                                    
                                    # 验证必要字段
                                    if processed_item["市场名称"] and processed_item["交易日期"]:
                                        processed_items.append(processed_item)
                                        
                                except Exception as e:
                                    self.logger.error(f"处理数据项失败: {str(e)}, 数据: {item}")
                                    continue
                            
                            all_items.extend(processed_items)
                            self.logger.info(f"获取市场 {market_id} 第 {page_num}/{pages} 页数据，本页 {len(processed_items)} 条")
                            
                            # 判断是否还有下一页
                            if page_num >= pages:
                                return all_items  # 到达最后一页，返回所有数据
                            page_num += 1
                            time.sleep(1)  # 翻页间隔
                        else:
                            return all_items  # 没有数据了就返回
                            
                        break  # 成功获取数据后跳出重试循环
                    
                    else:
                        error_msg = data.get("message", "Unknown error")
                        self.logger.error(f"API返回错误: {error_msg}")
                        if retry < max_retries - 1:
                            time.sleep(retry_delay)
                            continue
                        return all_items
                    
                except (requests.exceptions.RequestException, json.JSONDecodeError) as e:
                    self.logger.error(f"请求失败 (重试 {retry + 1}/{max_retries}): {str(e)}")
                    if retry < max_retries - 1:
                        time.sleep(retry_delay)
                        continue
                    return all_items
                
        return all_items

    def save_summary_data(self):
        """生成汇总数据"""
        try:
            print("\n=== 生成数据汇总 ===")
            all_data = []
            
            # 遍历日期目录
            for date_dir in os.listdir(self.data_dir):
                date_path = os.path.join(self.data_dir, date_dir)
                if not os.path.isdir(date_path) or date_dir == 'summary':
                    continue
                
                # 遍历市场目录
                for market_dir in os.listdir(date_path):
                    market_path = os.path.join(date_path, market_dir)
                    if not os.path.isdir(market_path):
                        continue
                    
                    # 读取该市场的所有CSV文件
                    csv_files = [f for f in os.listdir(market_path) if f.endswith('.csv')]
                    
                    for csv_file in csv_files:
                        try:
                            df = pd.read_csv(os.path.join(market_path, csv_file))
                            all_data.append(df)
                        except Exception as e:
                            self.logger.error(f"读取文件 {csv_file} 失败: {str(e)}")
            
            if all_data:
                # 合并所有数据
                summary_df = pd.concat(all_data, ignore_index=True)
                
                # 确保日期格式正确
                summary_df['交易日期'] = pd.to_datetime(summary_df['交易日期'])
                summary_df['爬取时间'] = pd.to_datetime(summary_df['爬取时间'])
                
                # 创建汇总目录
                summary_dir = os.path.join(self.data_dir, 'summary')
                os.makedirs(summary_dir, exist_ok=True)
                
                # 按日期分组保存
                for date, group in summary_df.groupby(summary_df['交易日期'].dt.date):
                    date_str = date.strftime('%Y%m%d')
                    
                    # 保存CSV
                    csv_file = os.path.join(summary_dir, f'summary_{date_str}.csv')
                    group.to_csv(csv_file, index=False, encoding='utf-8-sig')
                    print(f"✓ 已生成 {date_str} 的CSV汇总数据")
                    
                    # 保存JSON
                    json_file = os.path.join(summary_dir, f'summary_{date_str}.json')
                    group.to_json(json_file, orient='records', force_ascii=False, indent=2)
                    print(f"✓ 已生成 {date_str} 的JSON汇总数据")
                
                # 生成完整汇总
                summary_df = summary_df.sort_values(['交易日期', '省份', '市场名称', '品种名称'])
                
                # 保存完整汇总文件
                all_csv = os.path.join(summary_dir, 'summary_all.csv')
                summary_df.to_csv(all_csv, index=False, encoding='utf-8-sig')
                print(f"\n✓ 生成完整汇总CSV: {all_csv}")
                
                all_json = os.path.join(summary_dir, 'summary_all.json')
                summary_df.to_json(all_json, orient='records', force_ascii=False, indent=2)
                print(f"✓ 已生成完整汇总JSON: {all_json}")
                
                # 打印统计信息
                print("\n=== 数据统计 ===")
                print(f"总记录数: {len(summary_df)}")
                print(f"覆盖日期: {summary_df['交易日期'].min():%Y-%m-%d} 至 {summary_df['交易日期'].max():%Y-%m-%d}")
                print(f"省份数量: {summary_df['省份'].nunique()}")
                print(f"市场数量: {summary_df['市场名称'].nunique()}")
                print(f"品种数量: {summary_df['品种名称'].nunique()}")
                
            else:
                print("没有找到可用的数据文件！")
                
        except Exception as e:
            self.logger.error(f"生成汇总数据失败: {str(e)}")
            raise

    def merge_json_files(self):
        """合并所有JSON文件到一个总文件"""
        try:
            print("\n=== 合并JSON文件 ===")
            all_data = []
            
            # 遍历日期目录
            for date_dir in os.listdir(self.data_dir):
                date_path = os.path.join(self.data_dir, date_dir)
                if not os.path.isdir(date_path):
                    continue
                    
                # 遍历市场目录
                for market_dir in os.listdir(date_path):
                    market_path = os.path.join(date_path, market_dir)
                    if not os.path.isdir(market_path):
                        continue
                        
                    # 获取所有JSON文件
                    json_files = [f for f in os.listdir(market_path) if f.endswith('.json')]
                    
                    for json_file in json_files:
                        try:
                            with open(os.path.join(market_path, json_file), 'r', encoding='utf-8') as f:
                                data = json.load(f)
                                if isinstance(data, list):
                                    all_data.extend(data)
                                else:
                                    all_data.append(data)
                        except Exception as e:
                            self.logger.error(f"读取JSON文件 {json_file} 失: {str(e)}")
            
            if all_data:
                # 按日期排序
                all_data.sort(key=lambda x: (x.get('交易日期', ''), x.get('省份', ''), x.get('市场名称', '')))
                
                # 创建merged目录
                merged_dir = os.path.join(self.data_dir, 'merged')
                os.makedirs(merged_dir, exist_ok=True)
                
                # 保存合并后的JSON文件
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                merged_file = os.path.join(merged_dir, f'all_markets_{timestamp}.json')
                
                with open(merged_file, 'w', encoding='utf-8') as f:
                    json.dump(all_data, f, ensure_ascii=False, indent=2)
                
                print(f"\n✓ 已生成合并JSON文件: {merged_file}")
                print(f"  - 记录数: {len(all_data)}")
                print(f"  - 市场数量: {len(set(item.get('市场名称', '') for item in all_data))}")
                print(f"  - 省份数量: {len(set(item.get('省份', '') for item in all_data))}")
                
                # 同时生成CSV版本
                df = pd.DataFrame(all_data)
                csv_file = merged_file.replace('.json', '.csv')
                df.to_csv(csv_file, index=False, encoding='utf-8-sig')
                print(f"✓ 已生成合并CSV文件: {csv_file}")
                
            else:
                print("没有找到可用的JSON文件！")
                
        except Exception as e:
            self.logger.error(f"合并JSON文件失败: {str(e)}")
            raise

    def run(self, interval_minutes: int = 30):
        """运行爬虫，定期获取数据"""
        self.logger.info("开始运行市场数据爬虫...")
        
        # 获取导出配置
        self.get_export_config()
        
        # 询问是否需要合并历史JSON文件
        merge_choice = input("\n是否合并历史JSON文件？(y/n，默认n): ").strip().lower()
        if merge_choice == 'y':
            self.merge_json_files()
            if input("\n是否继续爬取新数据？(y/n，默认y): ").strip().lower() == 'n':
                return
        
        # 显示所有可选省份
        print("\n=== 省份选择 ===")
        for i, province in enumerate(self.provinces, 1):
            print(f"{i}. {province['name']}")
        
        # 获取用户输入
        while True:
            try:
                choices = input("\n请输入要爬取的省份序号(多个省份用号分隔，直接回车爬取所有省份): ").strip()
                if not choices:  # 直接回车，爬取所有省份
                    selected_provinces = self.provinces
                    break
                
                # 解析用户输
                indices = [int(x.strip()) for x in choices.split(",")]
                # 验证输入的序号是否有效
                if all(1 <= i <= len(self.provinces) for i in indices):
                    selected_provinces = [self.provinces[i-1] for i in indices]
                    break
                else:
                    print("输入序号无效，请重新输入！")
            except ValueError:
                print("输格式错误，请输入数字序号，多个序号用逗号分隔！")
        
        # 显示选择的省份
        print("\n已选择以下省份:")
        for province in selected_provinces:
            print(f"- {province['name']}")
        
        while True:
            try:
                data_changed = False  # 标记是否有数据变化
                
                # 遍历选定的省份
                for province in selected_provinces:
                    province_code = province["code"]
                    province_name = province["name"]
                    
                    self.logger.info(f"开始获取{province_name}的市场数据...")
                    
                    # 获取该省份的所有市场
                    url = f"{self.base_url}/priceQuotationController/getTodayMarketByProvinceCode"
                    params = {"code": province_code}
                    
                    response = requests.post(
                        url, 
                        headers=self.headers, 
                        params=params,
                        verify=False,
                        timeout=30
                    )
                    response.raise_for_status()
                    
                    data = response.json()
                    if data["code"] == 200 and "content" in data:
                        markets = data["content"]
                        
                        self.logger.info(f"{province_name}共有 {len(markets)} 个市场")
                        
                        for market in markets:
                            market_id = market.get("marketId")
                            market_name = market.get("marketName")
                            
                            if market_id and market_name:
                                details = self.fetch_market_details(market_id)
                                if details:
                                    # 添加省份信息
                                    for detail in details:
                                        detail["省份"] = province_name
                                        detail["省份代码"] = province_code
                                    
                                    # 保存该市场数据（如果有变化）
                                    if self.check_price_changed(market_name, details):
                                        self.save_market_data(market_name, details)
                                        self.logger.info(f"成功获取并保存 {market_name} 的 {len(details)} 条数据")
                                        data_changed = True
                                    
                                time.sleep(2)
                
                    # 处理一个省份后稍作等待
                    time.sleep(5)
                
                # 只有在数据有变化时才生成汇总
                if data_changed:
                    self.save_summary_data()
                else:
                    self.logger.info("本轮所有市场价格无变化")
                
                self.logger.info(f"本轮数据获取完成，等待 {interval_minutes} 分钟后进行下一次获取...")
                time.sleep(interval_minutes * 60)
                
            except Exception as e:
                self.logger.error(f"运行出错: {str(e)}")
                time.sleep(60)

def api_mode():
    """API模式下的数据获取"""
    crawler = MarketCrawler()
    data = []
    
    try:
        # 获取最新的市场数据
        for province in crawler.provinces:
            province_code = province["code"]
            markets = crawler.fetch_market_details(province_code)
            if markets:
                data.extend(markets)
        
        # 输出JSON格式数据
        print(json.dumps(data, ensure_ascii=False))
        return 0
    except Exception as e:
        print(json.dumps({
            "error": str(e)
        }, ensure_ascii=False))
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', default='normal', 
                      choices=['normal', 'api'],
                      help='运行模式: normal=普通模式, api=API模式')
    args = parser.parse_args()
    
    if args.mode == 'api':
        sys.exit(api_mode())
    else:
        crawler = MarketCrawler()
        crawler.run(interval_minutes=30) 
    
    # 最后一步，生成汇总数据
        crawler.save_summary_data()
        crawler.merge_json_files()
        crawler.logger.info("数据爬取完成！")

