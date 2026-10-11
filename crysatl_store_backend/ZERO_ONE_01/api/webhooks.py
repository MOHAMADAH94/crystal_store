import requests
import json
from django.utils import timezone
from .models import ExternalStore
from orders.models import Order, OrderDetails


def send_order_webhook(order, store):
    """إرسال webhook للمتجر الخارجي عند تحديث الطلب"""
    if not store.webhook_url:
        return False
    
    try:
        order_data = {
            'order_id': order.id,
            'user': order.user.username,
            'order_date': order.order_date.isoformat(),
            'is_finished': order.is_finished,
            'details': []
        }
        
        for detail in order.orderdetails_set.all():
            order_data['details'].append({
                'package_name': detail.Package.name,
                'gamer_id': detail.gamer_id,
                'quantity': detail.quantity,
                'price': str(detail.price),
                'final_price': str(detail.final_price),
                'status': detail.status,
                'response': detail.response
            })
        
        response = requests.post(
            store.webhook_url,
            json=order_data,
            headers={
                'Content-Type': 'application/json',
                'X-API-Key': store.api_key
            },
            timeout=10
        )
        
        return response.status_code == 200
    except Exception as e:
        print(f"Error sending webhook: {e}")
        return False


def receive_external_order(store, order_data):
    """استقبال طلب من متجر خارجي"""
    try:
        # التحقق من API Key
        if order_data.get('api_key') != store.api_key:
            return {'error': 'Invalid API Key'}, 400
        
        # إنشاء الطلب
        # يمكنك تخصيص هذا حسب احتياجاتك
        return {'message': 'Order received'}, 200
    except Exception as e:
        return {'error': str(e)}, 500



