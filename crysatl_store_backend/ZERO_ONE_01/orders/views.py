


import uuid
from decimal import Decimal, ROUND_DOWN
from django.shortcuts import get_object_or_404, render, redirect
from django.contrib import messages
from django.utils import timezone
from django.core.paginator import Paginator
from django.conf import settings
from django.db import transaction
import requests

from django.contrib.auth.decorators import login_required
from products.models import Package
from orders.models import Order, OrderDetails
from accounts.models import UserProfile, BalanceLog

PROFIT_CHOICES = settings.PROFIT_CHOICES  # استخدام إعدادات الزيادة بدلاً من الخصم


# --- دالة التعامل مع API خارجية (SW-Games) ---
def SW_GAMES_api(product_id, qty, player_id, extra_params=None, order_uuid=None):
    """
    تستدعي API الخاص بـ SW-Games لإنشاء طلب جديد.
    تعيد JSON أو None عند الفشل.
    
    Parameters:
    - product_id: معرف المنتج
    - qty: الكمية المطلوبة
    - player_id: معرف اللاعب (سيتم إرساله كـ Player_ID في dynamic_fields)
    - extra_params: حقول إضافية (اختياري)
    - order_uuid: معرف فريد للطلب لتجنب التكرار (اختياري)
    """
    from django.conf import settings
    from urllib.parse import urlencode
    
    # إنشاء UUID إذا لم يتم توفيره
    if not order_uuid:
        order_uuid = str(uuid.uuid4())
    
    # بناء URL مع query parameters
    base_url = f"{settings.SW_GAMES_API_BASE_URL}/requestorder/{product_id}/params"
    
    # بناء query parameters
    # تحويل الكمية إلى string للتأكد من التنسيق الصحيح
    # إذا كانت الكمية عشري، نرسلها كما هي
    # إذا كانت صحيحة، نرسلها كعدد صحيح
    if isinstance(qty, Decimal):
        # إذا كانت الكمية عدد صحيح (مثل 1.0)، نرسلها كعدد صحيح (1)
        if qty % 1 == 0:
            qty_str = str(int(qty))
        else:
            qty_str = str(qty)
    elif isinstance(qty, (int, float)):
        if isinstance(qty, float) and qty.is_integer():
            qty_str = str(int(qty))
        else:
            qty_str = str(qty)
    else:
        qty_str = str(qty)
    
    params = {
        'qty': qty_str,
        'uuid': order_uuid
    }
    
    # إضافة player_id كـ Player_ID (حقل ديناميكي)
    if player_id:
        params['Player_ID'] = player_id
    
    # إضافة أي حقول إضافية
    if extra_params:
        params.update(extra_params)
    
    # بناء URL مع query parameters
    url = f"{base_url}?{urlencode(params)}"
    
    # Headers المطلوبة
    headers = {
        'apiToken': settings.SW_GAMES_API_TOKEN,
        'Accept': 'application/json'
    }
    
    try:
        # استخدام GET request (حسب التوثيق)
        import logging
        logger = logging.getLogger(__name__)
        
        try:
            logger.info(f"[SW-GAMES API] Request URL: {url}")
            logger.info(f"[SW-GAMES API] Headers: {headers}")
        except:
            pass
        
        response = requests.get(url, headers=headers, timeout=30)
        
        # Logging للاستجابة
        try:
            logger.info(f"[SW-GAMES API] Response Status: {response.status_code}")
            logger.info(f"[SW-GAMES API] Response Text: {response.text[:500]}")
        except:
            pass
        
        # التحقق من status code
        if response.status_code == 201:
            # نجح الطلب (201 Created)
            try:
                response_data = response.json()
                # التحقق من أن error هو False (boolean) أو "false" (string)
                error_value = response_data.get('error')
                if error_value is False or error_value == False or (isinstance(error_value, str) and error_value.lower() == 'false'):
                    return response_data
                else:
                    # قد يكون طلب مكرر (duplicate) أو خطأ آخر
                    error_msg = response_data.get('message', 'Unknown error')
                    print(f"SW-Games API: {error_msg}")
                    logger.warning(f"[SW-GAMES API] Error in response: {error_msg}")
                    return response_data
            except ValueError as e:
                print(f"SW-Games API: Invalid JSON response: {e}")
                logger.error(f"[SW-GAMES API] Invalid JSON: {e}")
                return None
        elif response.status_code == 200:
            # نجح الطلب (200 OK)
            try:
                response_data = response.json()
                return response_data
            except ValueError as e:
                print(f"SW-Games API: Invalid JSON response: {e}")
                logger.error(f"[SW-GAMES API] Invalid JSON: {e}")
                return None
        else:
            # خطأ في الطلب - لكن نعيد الاستجابة حتى يمكن معالجتها
            try:
                error_data = response.json()
                error_message = error_data.get('message', f'HTTP {response.status_code}')
                print(f"SW-Games API Error ({response.status_code}): {error_message}")
                logger.error(f"[SW-GAMES API] Error ({response.status_code}): {error_message}")
                # إرجاع الاستجابة حتى يمكن معالجتها وحفظ رسالة الخطأ
                return error_data
            except:
                error_text = response.text[:500]
                print(f"SW-Games API Error ({response.status_code}): {error_text}")
                logger.error(f"[SW-GAMES API] Error ({response.status_code}): {error_text}")
                # إرجاع dict مع رسالة الخطأ
                return {
                    'error': True,
                    'message': f'HTTP {response.status_code}: {error_text}'
                }
            
    except requests.RequestException as e:
        print(f"مشكلة في الاتصال بـ SW-Games API: {e}")
        return None
    except ValueError as e:
        print(f"الاستجابة ليست JSON صالحة: {e}")
        return None
    except Exception as e:
        print(f"خطأ غير متوقع في SW-Games API: {e}")
        return None


# --- دالة التحقق من حالة الطلب من API ---
def check_order_status(external_order_id):
    """
    تتحقق من حالة الطلب من SW-Games API باستخدام Check Orders API.
    تعيد dict مع حالة الطلب أو None عند الفشل.
    
    Parameters:
    - external_order_id: رقم الطلب الخارجي (order_number)
    """
    from django.conf import settings
    import logging
    logger = logging.getLogger(__name__)
    
    if not external_order_id:
        return None
    
    # بناء URL للتحقق من حالة الطلب
    url = f"{settings.SW_GAMES_API_BASE_URL}/checkorders"
    params = {'order_ids': str(external_order_id)}
    
    # Headers المطلوبة
    headers = {
        'apiToken': settings.SW_GAMES_API_TOKEN,
        'Accept': 'application/json'
    }
    
    try:
        try:
            logger.info(f"[CHECK ORDER STATUS] Checking order: {external_order_id}")
        except:
            pass
        
        response = requests.get(url, headers=headers, params=params, timeout=30)
        
        # Logging للاستجابة
        try:
            logger.info(f"[CHECK ORDER STATUS] Response Status: {response.status_code}")
            logger.info(f"[CHECK ORDER STATUS] Response Text: {response.text[:500]}")
        except:
            pass
        
        if response.status_code == 200:
            try:
                response_data = response.json()
                if response_data.get('error') == False:
                    # البحث عن الطلب في البيانات
                    orders = response_data.get('data', {}).get('orders', [])
                    if orders:
                        order_data = orders[0]  # أول طلب في القائمة
                        return {
                            'status': order_data.get('status', ''),
                            'price': order_data.get('price', ''),
                            'gamer_data': order_data.get('gamer_data', {}),
                            'created_at': order_data.get('created_at', ''),
                            'order_number': order_data.get('order_number', ''),
                            'notes': order_data.get('notes', '')  # إضافة ملاحظات الطلب
                        }
                else:
                    error_message = response_data.get('message', 'Unknown error')
                    logger.warning(f"[CHECK ORDER STATUS] Error: {error_message}")
                    return None
            except ValueError as e:
                logger.error(f"[CHECK ORDER STATUS] Invalid JSON: {e}")
                return None
        else:
            try:
                error_data = response.json()
                error_message = error_data.get('message', f'HTTP {response.status_code}')
                logger.error(f"[CHECK ORDER STATUS] Error ({response.status_code}): {error_message}")
            except:
                error_text = response.text[:500]
                logger.error(f"[CHECK ORDER STATUS] Error ({response.status_code}): {error_text}")
            return None
            
    except requests.RequestException as e:
        logger.error(f"[CHECK ORDER STATUS] Request exception: {e}")
        return None
    except Exception as e:
        logger.error(f"[CHECK ORDER STATUS] Unexpected error: {e}")
        return None


# --- دالة تحديث حالة الطلب من API ---
def update_order_status_from_api(order_detail):
    """
    تحديث حالة OrderDetails بناءً على الرد من API.
    
    Parameters:
    - order_detail: OrderDetails object
    """
    import logging
    logger = logging.getLogger(__name__)
    
    if not order_detail or not order_detail.external_order_id:
        return False
    
    try:
        logger.info(f"[UPDATE ORDER STATUS] Updating order detail #{order_detail.id} with external_order_id: {order_detail.external_order_id}")
    except:
        pass
    
    # التحقق من حالة الطلب من API
    order_status_data = check_order_status(order_detail.external_order_id)
    
    if order_status_data:
        # تحديث الحالة بناءً على status من API
        api_status = order_status_data.get('status', '').lower()
        
        if api_status in ['done', 'completed', 'success', 'accepted', 'finished']:
            order_detail.status = "done"
        elif api_status in ['rejected', 'reject', 'failed', 'fail', 'error', 'declined', 'cancelled']:
            order_detail.status = "rejected"
            # استرداد المبلغ للمستخدم إذا كان الطلب مدفوعاً ولم يُسترد مسبقاً
            if order_detail.order.is_finished and not order_detail.has_been_refunded:
                try:
                    user_profile = order_detail.order.user.userprofile
                    refund_amount = Decimal(str(order_detail.final_price))
                    old_bal = user_profile.balance
                    user_profile.balance += refund_amount
                    user_profile.save()
                    BalanceLog.objects.create(
                        user_profile=user_profile,
                        old_balance=old_bal,
                        new_balance=user_profile.balance,
                        description=f'تحديث الرصيد — استرداد طلب #{order_detail.order.id}',
                    )
                    order_detail.has_been_refunded = True
                except Exception as e:
                    try:
                        logger = __import__('logging').getLogger(__name__)
                        logger.exception(f"[UPDATE ORDER STATUS] Refund failed for order detail #{order_detail.id}: {e}")
                    except Exception:
                        pass
        elif api_status in ['pending', 'processing', 'wait', 'waiting', 'in_progress', 'in-progress']:
            # الحالة processing تعني أن الطلب قيد المعالجة، نتركه pending
            order_detail.status = "pending"
        else:
            # أي حالة أخرى، نتركه pending
            order_detail.status = "pending"
        
        # حفظ ملاحظات الطلب (notes) في response إذا كانت موجودة
        # إذا لم تكن موجودة، نحفظ معلومات الحالة
        notes = order_status_data.get('notes', '')
        if notes:
            order_detail.response = str(notes)[:225]
        else:
            status_message = f"الحالة: {api_status}"
            if order_status_data.get('price'):
                status_message += f" | السعر: {order_status_data.get('price')}"
            order_detail.response = status_message[:225]
        order_detail.save()
        
        try:
            logger.info(f"[UPDATE ORDER STATUS] Order detail #{order_detail.id} updated to status: {order_detail.status}")
        except:
            pass
        
        return True
    else:
        try:
            logger.warning(f"[UPDATE ORDER STATUS] Failed to get order status for order detail #{order_detail.id}")
        except:
            pass
        return False


# --- إعادة محاولة إرسال الطلب للـ API (يُستخدم من الـ Admin) ---
def retry_api(order_detail):
    """
    يعيد إرسال OrderDetails معين للـ SW-Games API.
    يرجع (True, message) عند النجاح وإبقاء الحالة محدثة،
    أو (False, message) عند الفشل.
    يَستخدم UUID جديد لتجنب التكرار.
    """
    import logging
    logger = logging.getLogger(__name__)
    
    if not order_detail:
        return False, "تفاصيل الطلب غير موجودة"

    if not getattr(order_detail.Package, 'denomination_id', None):
        return False, "هذه الباقة لا تحتوي على معرف API (denomination_id)"

    try:
        logger.info(f"[RETRY API] Retrying order detail #{order_detail.id} - Product ID: {order_detail.Package.denomination_id}, Qty: {order_detail.quantity}, Player ID: {order_detail.gamer_id}")
    except:
        pass

    # إعادة إرسال للـ API
    from orders.views import check_order_status
    import uuid
    response = SW_GAMES_api(
        product_id=order_detail.Package.denomination_id,
        qty=order_detail.quantity,
        player_id=order_detail.gamer_id,
        order_uuid=str(uuid.uuid4()),
    )

    # Logging للاستجابة
    try:
        logger.info(f"[RETRY API] Response: {response}")
    except:
        pass

    # معالجة النتيجة وتحديث الحالة دون المساس بالأرصدة
    if response:
        error_value = response.get('error')
        response_message = response.get('message', '')
        
        # حفظ الرسالة/الرد في order_detail.response
        if response_message:
            order_detail.response = response_message[:225] if len(response_message) > 225 else response_message
        
        # التحقق من أن error هو False (boolean) أو "false" (string)
        if error_value is False or error_value == False or (isinstance(error_value, str) and error_value.lower() == 'false'):
            # نجح إرسال الطلب - حفظ external_order_id
            data = response.get('data', {})
            if isinstance(data, dict) and data.get('order_number'):
                order_detail.external_order_id = data.get('order_number')
            
            # التحقق من الحالة الفعلية من API (بدلاً من جعلها done مباشرة)
            if order_detail.external_order_id:
                order_status_data = check_order_status(order_detail.external_order_id)
                
                if order_status_data:
                    # تحديث الحالة بناءً على status من API
                    api_status = order_status_data.get('status', '').lower()
                    
                    if api_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                        order_detail.status = "done"
                    elif api_status in ['pending', 'processing', 'wait', 'waiting']:
                        order_detail.status = "pending"
                    elif api_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                        order_detail.status = "rejected"
                    else:
                        # إذا لم نجد status محدد، نعتبره pending
                        order_detail.status = "pending"
                    
                    # حفظ ملاحظات الطلب (notes) في response
                    notes = order_status_data.get('notes', '')
                    if notes:
                        order_detail.response = str(notes)[:225]
                    else:
                        # إذا لم تكن هناك notes، نحفظ معلومات الحالة
                        status_message = f"الحالة: {api_status}"
                        if order_status_data.get('price'):
                            status_message += f" | السعر: {order_status_data.get('price')}"
                        order_detail.response = status_message[:225]
                else:
                    # إذا لم نتمكن من الحصول على الحالة، نستخدم البيانات الأولية
                    order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                    
                    if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                        order_detail.status = "done"
                    elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                        order_detail.status = "rejected"
                    else:
                        order_detail.status = "pending"
                    
                    # حفظ ملاحظات الطلب (notes) في response
                    notes = data.get('notes', '') if isinstance(data, dict) else ''
                    if notes:
                        order_detail.response = str(notes)[:225]
                    elif response_message:
                        order_detail.response = response_message[:225]
                    else:
                        order_detail.response = 'تم إرسال الطلب بنجاح'[:225]
            else:
                # إذا لم يكن هناك external_order_id، نستخدم البيانات الأولية
                order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                
                if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                    order_detail.status = "done"
                elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                    order_detail.status = "rejected"
                else:
                    order_detail.status = "pending"
                
                # حفظ ملاحظات الطلب (notes) في response
                notes = data.get('notes', '') if isinstance(data, dict) else ''
                if notes:
                    order_detail.response = str(notes)[:225]
                elif response_message:
                    order_detail.response = response_message[:225]
                else:
                    order_detail.response = 'تم إرسال الطلب بنجاح'[:225]
            
            order_detail.save()
            try:
                logger.info(f"[RETRY API] Order status set to: {order_detail.status}, Message: {response_message}")
            except:
                pass
            return True, f"تم إرسال الطلب إلى الـ API بنجاح. {response_message}"
        else:
            # فشل الطلب - نتركه pending حتى يمكن إعادة المحاولة
            order_detail.status = 'pending'
            order_detail.save()
            try:
                logger.warning(f"[RETRY API] Order failed. Error: {response_message}")
            except:
                pass
            return False, response_message if response_message else 'فشل إرسال الطلب — الخدمة غير متوفرة حالياً'
    else:
        order_detail.status = 'pending'
        order_detail.response = 'فشل إرسال الطلب — الخدمة غير متوفرة حالياً'[:225]
        order_detail.save()
        try:
            logger.error(f"[RETRY API] SW-Games API returned None - no response")
        except:
            pass
        return False, "فشل إرسال الطلب — الخدمة غير متوفرة حالياً"


# --- إضافة باقة للسلة ---
@login_required(login_url='signin')
def add_to_cart(request, pack_id):
    if request.method != 'POST' or not request.user.is_authenticated:
        return redirect('/products')

    try:
        gamer_id = request.POST.get('gamer_id') or request.POST.get('hiddenGamerId', '').strip()
        pack = get_object_or_404(Package, id=pack_id)
        direct_payment = request.POST.get('direct_payment') == 'true'
        
        # تحويل الكمية إلى Decimal لدعم الكمية العشرية
        quantity_str = request.POST.get('quantity', '1')
        try:
            quantity = Decimal(str(quantity_str))
        except (ValueError, TypeError):
            messages.error(request, 'يجب إدخال كمية صحيحة')
            return redirect('package', id=pack.id)

        if not gamer_id:
            messages.error(request, 'يجب إدخال معرف اللاعب')
            return redirect('package', id=pack.id)
        
        # التحقق من أن gamer_id يحتوي على الأرقام والحروف الإنجليزية والرموز فقط
        import re
        pattern = r'^[a-zA-Z0-9@._\-+]+$'
        if not re.match(pattern, gamer_id):
            messages.error(request, 'معرف اللاعب يجب أن يحتوي على الأرقام والحروف الإنجليزية والرموز فقط (@, ., _, -, +)')
            return redirect('package', id=pack.id)

        if pack.is_custom and quantity <= 0:
            messages.error(request, 'يجب إدخال كمية صحيحة')
            return redirect('package', id=pack.id)
        
        # التحقق من السماح بالكمية العشرية
        if pack.is_custom:
            if not pack.product.allow_decimal_qty:
                # إذا لم يكن المنتج يسمح بالكمية العشرية، يجب أن تكون الكمية عدد صحيح
                # التحقق من أن الكمية عدد صحيح (بدون جزء عشري)
                if quantity % Decimal('1') != 0:
                    messages.error(request, 'هذا المنتج لا يسمح بالكمية العشرية. يجب إدخال عدد صحيح فقط')
                    return redirect('package', id=pack.id)
                quantity = quantity.quantize(Decimal('1'))
            # إذا كان المنتج يسمح بالكمية العشرية، نترك الكمية كما هي (Decimal)
        
        # التحقق من الحد الأدنى والأقصى للكمية للباقات المخصصة
        if pack.is_custom:
            if pack.product.min_custom_quantity:
                min_qty = Decimal(str(pack.product.min_custom_quantity))
                if quantity < min_qty:
                    messages.error(request, f'الكمية يجب أن تكون على الأقل {pack.product.min_custom_quantity}')
                    return redirect('package', id=pack.id)
            if pack.product.max_custom_quantity:
                max_qty = Decimal(str(pack.product.max_custom_quantity))
                if quantity > max_qty:
                    messages.error(request, f'الكمية يجب أن تكون على الأكثر {pack.product.max_custom_quantity}')
                    return redirect('package', id=pack.id)

        # حساب السعر بعد الزيادة حسب مستوى المستخدم (مطابق للمودال)
        user_profile = request.user.userprofile
        profit_rate = PROFIT_CHOICES.get(user_profile.level, Decimal('0.0'))
        
        if pack.is_custom:
            # للباقات المخصصة: حساب سعر الوحدة بعد الزيادة ثم الضرب في الكمية
            base_unit_price = pack.product.coins_price or Decimal('0.0')
            unit_price_after_profit = base_unit_price * (Decimal('1') + profit_rate)
            unit_price_after_profit = unit_price_after_profit.quantize(Decimal('0.000001'), rounding=ROUND_DOWN)
            final_price = unit_price_after_profit * quantity
        else:
            # للباقات العادية: حساب سعر الباقة بعد الزيادة مباشرة
            quantity = pack.quantity
            base_price = pack.price or Decimal('0.0')
            final_price = base_price * (Decimal('1') + profit_rate)
        
        final_price = final_price.quantize(Decimal('0.0001'), rounding=ROUND_DOWN)
        
        # تحويل السعر حسب عملة المستخدم
        from products.models import ExchangeRate
        if user_profile.currency == 'SYP':
            # تحويل من USD إلى SYP
            exchange_rate = ExchangeRate.get_current_rate()
            final_price = final_price * exchange_rate
            final_price = final_price.quantize(Decimal('0.0001'), rounding=ROUND_DOWN)

        with transaction.atomic():
            # الدفع المباشر - إنشاء طلب جديد مباشرة
            if direct_payment:
                # تنظيف أي طلبات قديمة غير مكتملة (اختياري - للأمان)
                old_orders = Order.objects.filter(
                    user=request.user,
                    is_finished=False
                )
                if old_orders.exists():
                    old_orders.delete()
                
                # إنشاء طلب جديد مباشرة للدفع المباشر
                order = Order.objects.create(
                    user=request.user,
                    order_date=timezone.now(),
                    is_finished=False
                )
            else:
                # للدفع العادي - البحث عن طلب غير مكتمل أو إنشاء واحد جديد
                order = Order.objects.filter(
                    user=request.user,
                    is_finished=False
                ).first()
                
                if not order:
                    order = Order.objects.create(
                        user=request.user,
                        order_date=timezone.now(),
                        is_finished=False
                    )
                else:
                    # حذف تفاصيل الطلب القديمة
                    order.orderdetails_set.all().delete()

            # تحويل الكمية إلى Decimal
            quantity_decimal = Decimal(str(quantity))
            
            order_detail = OrderDetails.objects.create(
                Package=pack,
                order=order,
                price=final_price,  # حفظ السعر بعد الزيادة مباشرة
                gamer_id=gamer_id,
                quantity=quantity_decimal,
                status='pending'
            )

            # إرسال الطلب مباشرة إلى API (قبل الدفع)
            if pack.denomination_id:
                from orders.views import check_order_status
                import uuid
                import logging
                logger = logging.getLogger(__name__)
                
                try:
                    logger.info(f"[ADD TO CART] Sending order to SW-Games API immediately - Product ID: {pack.denomination_id}, Qty: {quantity_decimal}, Player ID: {gamer_id}")
                except:
                    pass
                
                response = SW_GAMES_api(
                    product_id=pack.denomination_id,
                    qty=quantity_decimal,
                    player_id=gamer_id,
                    order_uuid=str(uuid.uuid4()),
                )
                
                # Logging للاستجابة
                try:
                    logger.info(f"[ADD TO CART] SW-Games API Response: {response}")
                except:
                    pass
                
                # معالجة الاستجابة وتحديث الحالة
                if response:
                    error_value = response.get('error')
                    response_message = response.get('message', '')
                    
                    # حفظ الرسالة/الرد في order_detail.response
                    if response_message:
                        order_detail.response = response_message[:225] if len(response_message) > 225 else response_message
                    
                    # التحقق من أن error هو False (boolean) أو "false" (string)
                    if error_value is False or error_value == False or (isinstance(error_value, str) and error_value.lower() == 'false'):
                        # نجح إرسال الطلب - حفظ external_order_id
                        data = response.get('data', {})
                        if isinstance(data, dict) and data.get('order_number'):
                            order_detail.external_order_id = data.get('order_number')
                        
                        # التحقق من الحالة الفعلية من API (بدلاً من جعلها done مباشرة)
                        if order_detail.external_order_id:
                            order_status_data = check_order_status(order_detail.external_order_id)
                            
                            if order_status_data:
                                # تحديث الحالة بناءً على status من API
                                api_status = order_status_data.get('status', '').lower()
                                
                                if api_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                    order_detail.status = "done"
                                elif api_status in ['pending', 'processing', 'wait', 'waiting']:
                                    order_detail.status = "pending"
                                elif api_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                    order_detail.status = "rejected"
                                else:
                                    # إذا لم نجد status محدد، نعتبره pending
                                    order_detail.status = "pending"
                                
                                # حفظ ملاحظات الطلب (notes) في response
                                notes = order_status_data.get('notes', '')
                                if notes:
                                    order_detail.response = str(notes)[:225]
                                else:
                                    # إذا لم تكن هناك notes، نحفظ معلومات الحالة
                                    status_message = f"الحالة: {api_status}"
                                    if order_status_data.get('price'):
                                        status_message += f" | السعر: {order_status_data.get('price')}"
                                    order_detail.response = status_message[:225]
                            else:
                                # إذا لم نتمكن من الحصول على الحالة، نستخدم البيانات الأولية
                                order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                                
                                if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                    order_detail.status = "done"
                                elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                    order_detail.status = "rejected"
                                else:
                                    order_detail.status = "pending"
                                
                                # حفظ ملاحظات الطلب (notes) في response
                                notes = data.get('notes', '') if isinstance(data, dict) else ''
                                if notes:
                                    order_detail.response = str(notes)[:225]
                                elif response_message:
                                    order_detail.response = response_message[:225]
                                else:
                                    order_detail.response = 'تم إرسال الطلب بنجاح'[:225]
                        else:
                            # إذا لم يكن هناك external_order_id، نستخدم البيانات الأولية
                            order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                            
                            if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                order_detail.status = "done"
                            elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                order_detail.status = "rejected"
                            else:
                                order_detail.status = "pending"
                            
                            # حفظ ملاحظات الطلب (notes) في response
                            notes = data.get('notes', '') if isinstance(data, dict) else ''
                            if notes:
                                order_detail.response = str(notes)[:225]
                            elif response_message:
                                order_detail.response = response_message[:225]
                            else:
                                order_detail.response = 'تم إرسال الطلب بنجاح'[:225]
                        
                        try:
                            logger.info(f"[ADD TO CART] Order sent successfully. External Order ID: {order_detail.external_order_id}, Status: {order_detail.status}")
                        except:
                            pass
                    else:
                        # فشل الطلب - نتركه pending حتى يمكن إعادة المحاولة
                        order_detail.status = 'pending'
                        try:
                            logger.warning(f"[ADD TO CART] Order failed. Error: {response_message}")
                        except:
                            pass
                else:
                    # إذا كان response None، نتركه pending
                    order_detail.status = 'pending'
                    order_detail.response = 'فشل إرسال الطلب — الخدمة غير متوفرة حالياً'[:225]
                    try:
                        logger.error(f"[ADD TO CART] SW-Games API returned None - no response")
                    except:
                        pass
                
                order_detail.save()

            # الدفع المباشر
            if direct_payment:
                order_detail.final_price = final_price
                order_detail.save()

                if user_profile.balance >= final_price:
                    user_profile.balance -= final_price
                    user_profile.save()
                    order.is_finished = True
                    order.save()

                    # الطلب تم إرساله مسبقاً عند الإنشاء، لا حاجة لإرساله مرة أخرى
                    # فقط نحدث الحالة إذا كان الطلب موجوداً في API
                    if order_detail.external_order_id:
                        # تحديث الحالة من API
                        update_order_status_from_api(order_detail)

                    messages.success(request, 'تم تأكيد الطلب بنجاح!')
                    return redirect('show_orders')
                else:
                    messages.error(request, 'الرصيد غير كافٍ لإتمام العملية')
                    return redirect('cart')

        messages.success(request, 'تمت إضافة الباقة إلى السلة')
        return redirect('cart')

    except Exception as e:
        # معالجة أخطاء الترميز بشكل آمن
        try:
            error_msg = str(e)
            # محاولة ترميز وفك الترميز لضمان التوافق
            error_msg = error_msg.encode('utf-8', errors='ignore').decode('utf-8')
        except:
            # في حالة فشل الترميز، نستخدم رسالة عامة
            error_msg = "حدث خطأ أثناء معالجة الطلب"
        
        messages.error(request, f'حدث خطأ أثناء معالجة الطلب: {error_msg}')
        return redirect('package', id=pack.id)


# --- عرض السلة ---
@login_required(login_url='signin')
def cart(request):
    order = Order.objects.filter(user=request.user, is_finished=False).first()
    orderdetails = order.orderdetails_set.all() if order else []
    total = sum(sub.price for sub in orderdetails) if orderdetails else 0

    context = {
        'order': order,
        'orderdetailes': orderdetails,
        'total': total
    }
    return render(request, 'orders/cart.html', context)


# --- إزالة عنصر من السلة ---
@login_required(login_url='signin')
def remove_from_cart(request, orderdetails_id):
    try:
        orderdetails = OrderDetails.objects.get(id=orderdetails_id, order__user=request.user)
        orderdetails.delete()
        if not OrderDetails.objects.filter(order=orderdetails.order).exists():
            orderdetails.order.delete()
        messages.success(request, 'تمت إزالة الباقة من السلة.')
    except OrderDetails.DoesNotExist:
        messages.error(request, 'تفاصيل الطلب غير موجودة.')

    return redirect('cart')


# --- عرض الطلبات ---
@login_required(login_url='signin')
def show_orders(request):
    all_orders = Order.objects.filter(user=request.user).order_by('-order_date')
    filter_value = request.GET.get('filter', 'all')

    if filter_value in ['done', 'pending', 'rejected']:
        all_orders = all_orders.filter(orderdetails__status=filter_value)

    total = 0
    if filter_value == 'not_finished':
        incomplete_orders = Order.objects.filter(user=request.user, is_finished=False)
        order_details = OrderDetails.objects.filter(order__in=incomplete_orders)
        total = sum(sub.price for sub in order_details)

    paginator = Paginator(all_orders, 10)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    context = {
        'all_orders': page_obj,
        'page_obj': page_obj,
        'total': total,
    }
    # تحديث حالة الطلبات pending التي لديها external_order_id
    pending_orders = OrderDetails.objects.filter(
        order__user=request.user,
        status='pending',
        external_order_id__isnull=False
    ).exclude(external_order_id='')
    
    updated_count = 0
    for detail in pending_orders:
        if update_order_status_from_api(detail):
            updated_count += 1
    
    if updated_count > 0:
        # إعادة تحميل الطلبات بعد التحديث
        all_orders = Order.objects.filter(user=request.user).order_by('-order_date')
        if filter_value in ['done', 'pending', 'rejected']:
            all_orders = all_orders.filter(orderdetails__status=filter_value)
        paginator = Paginator(all_orders, 10)
        page_obj = paginator.get_page(page_number)
        context['all_orders'] = page_obj
        context['page_obj'] = page_obj
    
    return render(request, 'orders/show_orders.html', context)


# --- الدفع ---
@login_required(login_url='signin')
def payment(request):
    order = Order.objects.filter(user=request.user, is_finished=False).first()
    if not order:
        return render(request, 'orders/payment.html', {})

    order_details = order.orderdetails_set.all()
    # السعر المحفوظ هو بالفعل السعر بعد الزيادة
    final_total = sum(Decimal(sub.price) for sub in order_details)

    if request.method == 'POST':
        if 'btnPayment' in request.POST:
            if order.is_finished:
                messages.warning(request, "تم تأكيد هذا الطلب مسبقًا.")
                return redirect('show_orders')

            if request.user.userprofile.balance >= final_total:
                request.user.userprofile.balance -= final_total
                request.user.userprofile.save()
                order.is_finished = True
                order.save()

                for detail in order_details:
                    detail.final_price = detail.price  # السعر المحفوظ هو نفسه السعر النهائي
                    
                    # إذا كان الطلب قد أُرسل مسبقاً إلى API، نحدث حالته فقط
                    if detail.external_order_id:
                        # تحديث الحالة من API
                        update_order_status_from_api(detail)
                    elif detail.Package.denomination_id:
                        from orders.views import check_order_status
                        import uuid
                        import logging
                        logger = logging.getLogger(__name__)
                        
                        try:
                            logger.info(f"[PAYMENT] Sending order to SW-Games API - Product ID: {detail.Package.denomination_id}, Qty: {detail.quantity}, Player ID: {detail.gamer_id}")
                        except:
                            pass
                        
                        response = SW_GAMES_api(
                            product_id=detail.Package.denomination_id,
                            qty=detail.quantity,
                            player_id=detail.gamer_id,
                            order_uuid=str(uuid.uuid4()),
                        )
                        
                        # Logging للاستجابة
                        try:
                            logger.info(f"[PAYMENT] SW-Games API Response: {response}")
                        except:
                            pass
                        
                        # التحقق من الاستجابة وتحديث الحالة
                        if response:
                            error_value = response.get('error')
                            response_message = response.get('message', '')
                            
                            # حفظ الرسالة/الرد في detail.response
                            if response_message:
                                detail.response = response_message[:225] if len(response_message) > 225 else response_message
                            
                            # التحقق من أن error هو False (boolean) أو "false" (string)
                            if error_value is False or error_value == False or (isinstance(error_value, str) and error_value.lower() == 'false'):
                                # نجح إرسال الطلب - حفظ external_order_id
                                data = response.get('data', {})
                                if isinstance(data, dict) and data.get('order_number'):
                                    detail.external_order_id = data.get('order_number')
                                
                                # التحقق من الحالة الفعلية من API (بدلاً من جعلها done مباشرة)
                                if detail.external_order_id:
                                    order_status_data = check_order_status(detail.external_order_id)
                                    
                                    if order_status_data:
                                        # تحديث الحالة بناءً على status من API
                                        api_status = order_status_data.get('status', '').lower()
                                        
                                        if api_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                            detail.status = "done"
                                        elif api_status in ['pending', 'processing', 'wait', 'waiting']:
                                            detail.status = "pending"
                                        elif api_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                            detail.status = "rejected"
                                        else:
                                            # إذا لم نجد status محدد، نعتبره pending
                                            detail.status = "pending"
                                        
                                        # حفظ ملاحظات الطلب (notes) في response
                                        notes = order_status_data.get('notes', '')
                                        if notes:
                                            detail.response = str(notes)[:225]
                                        else:
                                            # إذا لم تكن هناك notes، نحفظ معلومات الحالة
                                            status_message = f"الحالة: {api_status}"
                                            if order_status_data.get('price'):
                                                status_message += f" | السعر: {order_status_data.get('price')}"
                                            detail.response = status_message[:225]
                                    else:
                                        # إذا لم نتمكن من الحصول على الحالة، نستخدم البيانات الأولية
                                        order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                                        
                                        if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                            detail.status = "done"
                                        elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                            detail.status = "rejected"
                                        else:
                                            detail.status = "pending"
                                        
                                        # حفظ ملاحظات الطلب (notes) في response
                                        notes = data.get('notes', '') if isinstance(data, dict) else ''
                                        if notes:
                                            detail.response = str(notes)[:225]
                                        elif response_message:
                                            detail.response = response_message[:225]
                                        else:
                                            detail.response = 'تم إرسال الطلب بنجاح'[:225]
                                else:
                                    # إذا لم يكن هناك external_order_id، نستخدم البيانات الأولية
                                    order_status = data.get('status', '').lower() if isinstance(data, dict) and data.get('status') else ''
                                    
                                    if order_status in ['done', 'completed', 'success', 'accepted', 'finished']:
                                        detail.status = "done"
                                    elif order_status in ['rejected', 'reject', 'failed', 'fail', 'error']:
                                        detail.status = "rejected"
                                    else:
                                        detail.status = "pending"
                                    
                                    # حفظ ملاحظات الطلب (notes) في response
                                    notes = data.get('notes', '') if isinstance(data, dict) else ''
                                    if notes:
                                        detail.response = str(notes)[:225]
                                    elif response_message:
                                        detail.response = response_message[:225]
                                    else:
                                        detail.response = 'تم إرسال الطلب بنجاح'[:225]
                                
                                try:
                                    logger.info(f"[PAYMENT] Order status set to: {detail.status}, Message: {response_message}")
                                except:
                                    pass
                            else:
                                # فشل الطلب - نتركه pending حتى يمكن إعادة المحاولة
                                detail.status = 'pending'
                                try:
                                    logger.warning(f"[PAYMENT] Order failed. Error: {response_message}")
                                except:
                                    pass
                        else:
                            # إذا كان response None، نتركه pending
                            detail.status = 'pending'
                            detail.response = 'فشل إرسال الطلب — الخدمة غير متوفرة حالياً'[:225]
                            try:
                                logger.error(f"[PAYMENT] SW-Games API returned None - no response")
                            except:
                                pass
                    detail.save()

                messages.success(request, 'تم تأكيد الطلب وجارٍ معالجته.')
                return redirect('show_orders')
            else:
                messages.warning(request, "الرصيد غير كافٍ للقيام بالدفع.")

        elif 'btnReject' in request.POST:
            # عند الرفض، نعيد الرصيد الكامل (السعر بعد الزيادة)
            request.user.userprofile.balance += final_total
            request.user.userprofile.save()
            for detail in order_details:
                detail.status = 'rejected'
                detail.save()
            order.save()

    context = {
        'order': order,
        'order_details': order_details,
        'total': final_total,  # السعر الإجمالي (بعد الزيادة)
        'balance': request.user.userprofile.balance,
        'profit': Decimal('0.0'),  # لا نعرض نسبة الربح
        'final_total': final_total,  # نفس السعر الإجمالي
    }
    return render(request, 'orders/payment.html', context)


# --- تحديث حالة طلب محدد ---
@login_required(login_url='signin')
def update_order_status(request, order_detail_id):
    """
    تحديث حالة طلب محدد من API.
    """
    try:
        order_detail = OrderDetails.objects.get(
            id=order_detail_id,
            order__user=request.user
        )
        
        if order_detail.external_order_id:
            if update_order_status_from_api(order_detail):
                messages.success(request, f'تم تحديث حالة الطلب إلى: {order_detail.get_status_display()}')
            else:
                messages.warning(request, 'فشل تحديث حالة الطلب من API')
        else:
            messages.warning(request, 'هذا الطلب لا يحتوي على رقم طلب خارجي')
            
    except OrderDetails.DoesNotExist:
        messages.error(request, 'الطلب غير موجود')
    
    return redirect('show_orders')


# --- تحديث جميع الطلبات pending ---
@login_required(login_url='signin')
def update_all_pending_orders(request):
    """
    تحديث حالة جميع الطلبات pending التي لديها external_order_id.
    """
    pending_orders = OrderDetails.objects.filter(
        order__user=request.user,
        status='pending',
        external_order_id__isnull=False
    ).exclude(external_order_id='')
    
    updated_count = 0
    for detail in pending_orders:
        if update_order_status_from_api(detail):
            updated_count += 1
    
    if updated_count > 0:
        messages.success(request, f'تم تحديث {updated_count} طلب بنجاح')
    else:
        messages.info(request, 'لا توجد طلبات تحتاج إلى تحديث')
    
    return redirect('show_orders')




