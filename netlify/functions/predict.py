import json
import sys
import os

# 添加项目根目录到 Python 路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

from api_server import app
from fastapi import Request
from fastapi.responses import JSONResponse

def handler(event, context):
    """Netlify Functions handler for predict endpoint"""
    try:
        # 解析请求体
        body = json.loads(event.get('body', '{}'))
        
        # 模拟 FastAPI 请求
        if event['httpMethod'] == 'POST':
            # 导入预测逻辑
            from market_crawler import MarketCrawler
            
            symbol = body.get('symbol', 'AAPL')
            days = body.get('days', 7)
            
            crawler = MarketCrawler()
            prediction = crawler.predict_price(symbol, days)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps({
                    'symbol': symbol,
                    'days': days,
                    'prediction': prediction,
                    'status': 'success'
                })
            }
        else:
            return {
                'statusCode': 405,
                'body': json.dumps({'error': 'Method not allowed'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'status': 'error'
            })
        }
