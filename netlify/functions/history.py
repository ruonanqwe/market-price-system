import json
import sys
import os

# 添加项目根目录到 Python 路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

def handler(event, context):
    """Netlify Functions handler for history endpoint"""
    try:
        # 从路径参数获取股票代码
        path = event.get('path', '')
        symbol = path.split('/')[-1] if '/' in path else 'AAPL'
        
        # 导入数据库管理器
        from database_manager import DatabaseManager
        
        db_manager = DatabaseManager()
        history_data = db_manager.get_price_history(symbol, limit=30)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET, OPTIONS'
            },
            'body': json.dumps({
                'symbol': symbol,
                'history': history_data,
                'status': 'success'
            })
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
