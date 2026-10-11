from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.authentication import TokenAuthentication
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db import transaction
from django.utils import timezone
from decimal import Decimal
import json

from products.models import Category, Product, Package, Agent, ExchangeRate
from orders.models import Order, OrderDetails
from accounts.models import UserProfile, PaymentMethod, BalanceLog, Notification, UserNotification, Balance_add
from .models import APIKey, ExternalStore
from .serializers import (
    UserSerializer, UserProfileSerializer, CategorySerializer, ProductSerializer,
    PackageSerializer, OrderSerializer, CreateOrderSerializer, PaymentMethodSerializer,
    BalanceLogSerializer, NotificationSerializer, APIKeySerializer, ExternalStoreSerializer,
    AgentSerializer, BalanceAddSerializer
)
from .authentication import APIKeyAuthentication
from .webhooks import send_order_webhook
from zeroone01.settings import PROFIT_CHOICES


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض الفئات"""
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        # إرجاع الفئات الأساسية فقط (التي ليس لها parent_category)
        parent_only = self.request.query_params.get('parent_only', 'false').lower() == 'true'
        if parent_only:
            return Category.objects.filter(parent_category__isnull=True).order_by('ordering')
        return Category.objects.all().order_by('ordering')


class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض المنتجات"""
    queryset = Product.objects.filter(is_active=True)
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = Product.objects.filter(is_active=True)
        category_id = self.request.query_params.get('category', None)
        if category_id:
            queryset = queryset.filter(category_id=category_id)
        return queryset.order_by('-created_at')


class PackageViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض الباقات"""
    queryset = Package.objects.filter(is_active=True)
    serializer_class = PackageSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = Package.objects.filter(is_active=True)
        product_id = self.request.query_params.get('product', None)
        if product_id:
            queryset = queryset.filter(product_id=product_id)
        return queryset.order_by('-id')


class OrderViewSet(viewsets.ModelViewSet):
    """إدارة الطلبات - يدعم Token و API Key"""
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [TokenAuthentication, APIKeyAuthentication]  # دعم Token و API Keys
    
    def get_queryset(self):
        import logging
        logger = logging.getLogger(__name__)
        
        # التأكد من أن المستخدم مصادق عليه
        if not hasattr(self.request, 'user') or not self.request.user or not self.request.user.is_authenticated:
            logger.warning("[OrderViewSet] User not authenticated")
            return Order.objects.none()
        
        # الحصول على معلومات المستخدم
        user = self.request.user
        user_id = user.id
        username = user.username
        
        # Logging معلومات المصادقة
        try:
            auth_header = self.request.META.get('HTTP_AUTHORIZATION', '')
            logger.info(f"[OrderViewSet] Request from user: {username} (ID: {user_id}), Auth: {auth_header[:20]}...")
        except:
            pass
        
        queryset = Order.objects.select_related('user').prefetch_related(
            'orderdetails_set__Package__product__category'
        ).order_by('-id')
        
        # فلترة صارمة: جميع المستخدمين (بما في ذلك الموظفين والادمن) يرون فقط طلباتهم
        # الإدارة والموظفين يديرون الأمور من لوحة التحكم فقط
        filtered_queryset = queryset.filter(user__id=user_id)
        
        # Logging للتأكد من الفلترة
        try:
            total_count = queryset.count()
            filtered_count = filtered_queryset.count()
            is_staff = user.is_staff
            logger.info(f"[OrderViewSet] User: {username} (ID: {user_id}, Staff: {is_staff}), Total orders in DB: {total_count}, Filtered orders: {filtered_count}")
            
            # التحقق من أن جميع الطلبات المفلترة تنتمي للمستخدم
            for order in filtered_queryset[:10]:  # فحص أول 10 طلبات
                if order.user_id != user_id:
                    logger.error(f"[OrderViewSet] SECURITY ISSUE: Order {order.id} belongs to user {order.user_id} ({order.user.username}) but returned for user {user_id} ({username})!")
                    # إرجاع queryset فارغ في حالة اكتشاف مشكلة أمنية
                    return Order.objects.none()
        except Exception as e:
            logger.error(f"[OrderViewSet] Error in logging: {str(e)}")
        
        return filtered_queryset
    
    def list(self, request, *args, **kwargs):
        """Override list method للتأكد من الفلترة الصحيحة وتحديث الحالة تلقائياً"""
        import logging
        logger = logging.getLogger(__name__)
        
        # التأكد من أن المستخدم مصادق عليه
        if not request.user or not request.user.is_authenticated:
            logger.warning("[OrderViewSet.list] User not authenticated")
            from rest_framework.response import Response
            return Response([], status=200)
        
        # Logging معلومات الطلب
        try:
            logger.info(f"[OrderViewSet.list] User: {request.user.username} (ID: {request.user.id}) requesting orders")
        except:
            pass
        
        # استخدام get_queryset للحصول على الطلبات المفلترة
        queryset = self.filter_queryset(self.get_queryset())
        
        # تحديث حالة الطلبات pending التي لديها external_order_id (مثل الموقع)
        from orders.views import update_order_status_from_api
        from orders.models import OrderDetails
        
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
            # إعادة تحميل queryset بعد التحديث
            queryset = self.filter_queryset(self.get_queryset())
            try:
                logger.info(f"[OrderViewSet.list] Updated {updated_count} pending orders")
            except:
                pass
        
        # التحقق النهائي من أن جميع الطلبات تنتمي للمستخدم (لجميع المستخدمين بما في ذلك الموظفين)
        for order in queryset:
            if order.user_id != request.user.id:
                logger.error(f"[OrderViewSet.list] SECURITY ISSUE: Order {order.id} belongs to user {order.user_id} but returned for user {request.user.id}!")
                from rest_framework.response import Response
                return Response([], status=200)
        
        # استخدام الـ serializer العادي
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    def get_serializer_context(self):
        """إضافة context للـ serializer لتمرير request"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def perform_update(self, serializer):
        """عند تحديث الطلب، إرسال webhook للمتاجر الخارجية"""
        order = serializer.save()
        # إرسال webhook لجميع المتاجر الخارجية النشطة
        for store in ExternalStore.objects.filter(is_active=True):
            send_order_webhook(order, store)
    
    @action(detail=False, methods=['post'])
    def create_order(self, request):
        """إنشاء طلب جديد"""
        try:
            serializer = CreateOrderSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                package = Package.objects.get(id=serializer.validated_data['package_id'])
                quantity = serializer.validated_data['quantity']
                gamer_id = serializer.validated_data['gamer_id']
                
                # تحويل الكمية إلى Decimal
                quantity = Decimal(str(quantity))
                
                # حساب السعر حسب نوع الباقة
                if package.is_custom:
                    # للباقات المخصصة: السعر = العدد (من المستخدم) × سعر الوحدة (من المنتج)
                    coins_price = package.product.coins_price
                    if coins_price is None or coins_price <= 0:
                        return Response(
                            {'error': 'سعر الوحدة غير متوفر للباقة المخصصة'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    price = Decimal(str(coins_price)) * quantity
                else:
                    # للباقات العادية: السعر مكتوب ضمن الباقة نفسها (ثابت)
                    if package.price is None:
                        return Response(
                            {'error': 'سعر الباقة غير متوفر'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    price = package.price
                
                # حساب الخصم حسب المستوى
                user_profile = request.user.userprofile
                discount = PROFIT_CHOICES.get(user_profile.level, Decimal('0.01'))
                final_price = price * (1 + discount)
                
                # تحويل السعر حسب عملة المستخدم
                if user_profile.currency == 'SYP':
                    # تحويل من USD إلى SYP
                    exchange_rate = ExchangeRate.get_current_rate()
                    final_price = final_price * exchange_rate
                
                # التحقق من الرصيد
                if user_profile.balance < final_price:
                    return Response(
                        {
                            'error': 'الرصيد غير كافي',
                            'required_balance': str(final_price),
                            'available_balance': str(user_profile.balance),
                            'shortage': str(final_price - user_profile.balance),
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # إنشاء الطلب
                with transaction.atomic():
                    order = Order.objects.create(
                        user=request.user,
                        order_date=timezone.now(),
                        is_finished=True  # تم الدفع لأن الرصيد تم خصمه
                    )
                    
                    order_detail = OrderDetails.objects.create(
                        Package=package,
                        order=order,
                        price=price,
                        final_price=final_price,
                        gamer_id=gamer_id,
                        quantity=quantity,
                        status='pending'
                    )
                    
                    # خصم الرصيد
                    user_profile.balance -= final_price
                    user_profile.save()
                    
                    # تسجيل التغيير
                    BalanceLog.objects.create(
                        user_profile=user_profile,
                        old_balance=user_profile.balance + final_price,
                        new_balance=user_profile.balance,
                        description=f'تحديث الرصيد — طلب #{order.id}'
                    )
                    
                    # إرسال الطلب مباشرة إلى SW-Games API
                    if package.denomination_id:
                        from orders.views import SW_GAMES_api, check_order_status
                        import uuid
                        import logging
                        logger = logging.getLogger(__name__)
                        
                        try:
                            logger.info(f"[API CREATE ORDER] Sending order to SW-Games API - Product ID: {package.denomination_id}, Qty: {quantity}, Player ID: {gamer_id}")
                        except:
                            pass
                        
                        response = SW_GAMES_api(
                            product_id=package.denomination_id,
                            qty=quantity,
                            player_id=gamer_id,
                            order_uuid=str(uuid.uuid4()),
                        )
                        
                        # Logging للاستجابة
                        try:
                            logger.info(f"[API CREATE ORDER] SW-Games API Response: {response}")
                        except:
                            pass
                        
                        # معالجة الاستجابة وتحديث الحالة
                        if response:
                            error_value = response.get('error')
                            response_message = response.get('message', '')
                            
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
                                    logger.info(f"[API CREATE ORDER] Order sent successfully. External Order ID: {order_detail.external_order_id}, Status: {order_detail.status}, Response: {order_detail.response}")
                                except:
                                    pass
                            else:
                                # فشل الطلب - نتركه pending حتى يمكن إعادة المحاولة
                                order_detail.status = 'pending'
                                order_detail.response = response_message[:225] if response_message else 'فشل إرسال الطلب'[:225]
                                try:
                                    logger.warning(f"[API CREATE ORDER] Order failed. Error: {response_message}")
                                except:
                                    pass
                        else:
                            # إذا كان response None، نتركه pending
                            order_detail.status = 'pending'
                            order_detail.response = 'فشل إرسال الطلب — الخدمة غير متوفرة حالياً'[:225]
                            try:
                                logger.error(f"[API CREATE ORDER] SW-Games API returned None - no response")
                            except:
                                pass
                        
                        # إذا أصبح الطلب مرفوضاً، نسترد المبلغ المخصوم
                        if order_detail.status == 'rejected' and not order_detail.has_been_refunded:
                            old_bal = user_profile.balance
                            user_profile.balance += final_price
                            user_profile.save()
                            BalanceLog.objects.create(
                                user_profile=user_profile,
                                old_balance=old_bal,
                                new_balance=user_profile.balance,
                                description=f'تحديث الرصيد — استرداد طلب #{order.id}',
                            )
                            order_detail.has_been_refunded = True
                        
                        order_detail.save()
                
                # تحديث user_profile من قاعدة البيانات للحصول على الرصيد المحدث
                user_profile.refresh_from_db()
                
                # إرسال webhook للمتاجر الخارجية (في الخلفية، لا ننتظرها)
                try:
                    for store in ExternalStore.objects.filter(is_active=True):
                        try:
                            send_order_webhook(order, store)
                        except Exception as webhook_error:
                            # لا نوقف العملية إذا فشل webhook
                            print(f"Webhook error for store {store.id}: {webhook_error}")
                except Exception as e:
                    # لا نوقف العملية إذا فشل webhook
                    print(f"Error sending webhooks: {e}")
                
                # إرجاع response بسيط لتجنب مشاكل serialization
                # الطلب يتم إنشاؤه بنجاح حتى لو كان هناك خطأ في webhook أو serialization
                try:
                    message = 'تم إنشاء الطلب بنجاح'.encode('utf-8', errors='ignore').decode('utf-8')
                except:
                    message = 'Order created successfully'
                
                return Response(
                    {
                        'id': order.id,
                        'message': message,
                        'updated_balance': str(user_profile.balance),
                        'order_date': order.order_date.isoformat() if order.order_date else None,
                        'is_finished': order.is_finished,
                    },
                    status=status.HTTP_201_CREATED
                )
            except Package.DoesNotExist:
                return Response(
                    {'error': 'الباقة غير موجودة'},
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as inner_e:
                # معالجة أي أخطاء داخلية
                import traceback
                import logging
                logger = logging.getLogger(__name__)
                try:
                    error_trace = traceback.format_exc()
                    error_safe = str(inner_e).encode('utf-8', errors='ignore').decode('utf-8')
                    logger.error(f"Error in create_order inner try: {error_safe}")
                    logger.error(f"Traceback: {error_trace}")
                except:
                    pass
                
                try:
                    error_msg = str(inner_e).encode('utf-8', errors='ignore').decode('utf-8')
                except:
                    error_msg = "حدث خطأ أثناء إنشاء الطلب"
                
                return Response(
                    {'error': error_msg},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        except Exception as outer_e:
            # معالجة أخطاء عامة
            import traceback
            import logging
            logger = logging.getLogger(__name__)
            try:
                error_trace = traceback.format_exc()
                error_safe = str(outer_e).encode('utf-8', errors='ignore').decode('utf-8')
                logger.error(f"Error in create_order outer try: {error_safe}")
                logger.error(f"Traceback: {error_trace}")
            except:
                pass
            
            try:
                error_msg = str(outer_e).encode('utf-8', errors='ignore').decode('utf-8')
            except:
                error_msg = "حدث خطأ غير متوقع"
            
            return Response(
                {'error': error_msg},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UserProfileViewSet(viewsets.ModelViewSet):
    """عرض وتعديل ملف المستخدم - يدعم Token و API Key"""
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [TokenAuthentication, APIKeyAuthentication]  # دعم Token و API Keys
    
    def get_queryset(self):
        return UserProfile.objects.filter(user=self.request.user)
    
    def get_object(self):
        """الحصول على ملف المستخدم الحالي"""
        profile, created = UserProfile.objects.get_or_create(
            user=self.request.user,
            defaults={
                'address': '---',
                'address2': '---',
                'city': '---',
                'state': '---',
                'phone': '0000000000',
                'balance': 0.0,
                'level': 'vip1',
            }
        )
        return profile
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """الحصول على ملف المستخدم الحالي"""
        profile = self.get_object()
        serializer = self.get_serializer(profile)
        return Response(serializer.data)
    
    @action(detail=False, methods=['put', 'patch'])
    def update_profile(self, request):
        """تحديث ملف المستخدم الحالي"""
        profile = self.get_object()
        serializer = self.get_serializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def balance_history(self, request):
        """سجل تغييرات الرصيد"""
        profile = request.user.userprofile
        logs = BalanceLog.objects.filter(user_profile=profile).order_by('-change_date')
        serializer = BalanceLogSerializer(logs, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def send_money(self, request):
        """إرسال طلب إضافة رصيد"""
        try:
            amount = Decimal(str(request.data.get('amount', 0)))
            payment_method_id = request.data.get('payment_method')
            receipt = request.FILES.get('receipt')
            
            if not receipt:
                return Response(
                    {'error': 'يرجى تحميل إيصال الدفع'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if not payment_method_id:
                return Response(
                    {'error': 'يرجى اختيار طريقة الدفع'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            payment_method = PaymentMethod.objects.get(id=payment_method_id)
            
            # حساب المبلغ بعد الخصم
            discount_percentage = payment_method.discount_percentage
            discounted_amount = amount * (1 - discount_percentage / 100)
            
            # إنشاء طلب إضافة الرصيد
            balance_add = Balance_add.objects.create(
                user=request.user,
                amount=discounted_amount,
                receipt=receipt,
                is_processed=False,
                payment_method=payment_method
            )
            
            return Response({
                'message': 'تم إرسال طلب الدفعة بنجاح',
                'id': balance_add.id,
                'amount': str(discounted_amount),
            }, status=status.HTTP_201_CREATED)
        except PaymentMethod.DoesNotExist:
            return Response(
                {'error': 'طريقة الدفع غير موجودة'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['get'])
    def balance_add_requests(self, request):
        """الحصول على طلبات إضافة الرصيد للمستخدم"""
        balance_adds = Balance_add.objects.filter(user=request.user).order_by('-created_at')
        serializer = BalanceAddSerializer(balance_adds, many=True, context={'request': request})
        return Response(serializer.data)


class PaymentMethodViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض طرق الدفع"""
    queryset = PaymentMethod.objects.all()
    serializer_class = PaymentMethodSerializer
    permission_classes = [permissions.AllowAny]


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض الإشعارات"""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user_notifications = UserNotification.objects.filter(user=self.request.user)
        return Notification.objects.filter(
            usernotification__in=user_notifications
        ).order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """تحديد الإشعار كمقروء"""
        notification = self.get_object()
        user_notification, created = UserNotification.objects.get_or_create(
            user=request.user,
            notification=notification
        )
        user_notification.read = True
        user_notification.save()
        return Response({'status': 'marked as read'})


class APIKeyViewSet(viewsets.ModelViewSet):
    """إدارة API Keys - يدعم Token و API Key"""
    serializer_class = APIKeySerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [TokenAuthentication, APIKeyAuthentication]  # دعم Token و API Keys
    
    def get_queryset(self):
        return APIKey.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ExternalStoreViewSet(viewsets.ModelViewSet):
    """إدارة المتاجر الخارجية"""
    serializer_class = ExternalStoreSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        if self.request.user.is_staff:
            return ExternalStore.objects.all()
        return ExternalStore.objects.none()


class AgentViewSet(viewsets.ReadOnlyModelViewSet):
    """عرض الوكلاء"""
    queryset = Agent.objects.filter(is_active=True)
    serializer_class = AgentSerializer
    permission_classes = [permissions.AllowAny]


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register(request):
    """تسجيل مستخدم جديد"""
    username = request.data.get('username')
    email = request.data.get('email')
    password = request.data.get('password')
    
    if not username or not email or not password:
        return Response(
            {'error': 'يجب إدخال جميع الحقول'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    if User.objects.filter(username=username).exists():
        return Response(
            {'error': 'اسم المستخدم موجود بالفعل'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = User.objects.create_user(username=username, email=email, password=password)
    token, created = Token.objects.get_or_create(user=user)
    
    return Response({
        'token': token.key,
        'user': UserSerializer(user).data
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def login(request):
    """تسجيل الدخول"""
    username = request.data.get('username')
    password = request.data.get('password')
    
    if not username or not password:
        return Response(
            {'error': 'يجب إدخال اسم المستخدم وكلمة المرور'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = authenticate(username=username, password=password)
    if user:
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user': UserSerializer(user).data
        })
    else:
        return Response(
            {'error': 'بيانات الدخول غير صحيحة'},
            status=status.HTTP_401_UNAUTHORIZED
        )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def external_order(request):
    """استقبال طلب من متجر خارجي - يتم إنشاء الطلب على حساب المستخدم المرتبط بالمتجر"""
    api_key = request.META.get('HTTP_X_API_KEY') or request.data.get('api_key')
    
    if not api_key:
        return Response(
            {'error': 'API Key مطلوب'},
            status=status.HTTP_401_UNAUTHORIZED
        )
    
    try:
        store = ExternalStore.objects.get(api_key=api_key, is_active=True)
        
        # التحقق من وجود مستخدم مرتبط بالمتجر
        if not store.user:
            return Response(
                {'error': 'المتجر غير مرتبط بمستخدم'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # استخدام نفس منطق create_order لكن على حساب المستخدم المرتبط بالمتجر
        try:
            serializer = CreateOrderSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            package = Package.objects.get(id=serializer.validated_data['package_id'])
            quantity = serializer.validated_data['quantity']
            gamer_id = serializer.validated_data['gamer_id']
            
            # حساب السعر حسب نوع الباقة
            if package.is_custom:
                coins_price = package.product.coins_price
                if coins_price is None or coins_price <= 0:
                    return Response(
                        {'error': 'سعر الوحدة غير متوفر للباقة المخصصة'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                price = Decimal(str(coins_price)) * Decimal(str(quantity))
            else:
                if package.price is None:
                    return Response(
                        {'error': 'سعر الباقة غير متوفر'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                price = package.price
            
            # حساب الخصم حسب المستوى
            user_profile = store.user.userprofile
            discount = PROFIT_CHOICES.get(user_profile.level, Decimal('0.01'))
            final_price = price * (1 + discount)
            
            # التحقق من الرصيد
            if user_profile.balance < final_price:
                return Response(
                    {
                        'error': 'الرصيد غير كافي',
                        'required_balance': str(final_price),
                        'available_balance': str(user_profile.balance),
                        'shortage': str(final_price - user_profile.balance),
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # إنشاء الطلب على حساب المستخدم المرتبط بالمتجر
            with transaction.atomic():
                order = Order.objects.create(
                    user=store.user,  # استخدام المستخدم المرتبط بالمتجر
                    order_date=timezone.now(),
                    is_finished=True
                )
                
                order_detail = OrderDetails.objects.create(
                    Package=package,
                    order=order,
                    price=price,
                    final_price=final_price,
                    gamer_id=gamer_id,
                    quantity=quantity,
                    status='pending'
                )
                
                # خصم الرصيد من حساب المستخدم المرتبط بالمتجر
                user_profile.balance -= final_price
                user_profile.save()
                
                # تسجيل التغيير
                BalanceLog.objects.create(
                    user_profile=user_profile,
                    old_balance=user_profile.balance + final_price,
                    new_balance=user_profile.balance,
                    description=f'تحديث الرصيد — متجر خارجي #{order.id}'
                )
            
            user_profile.refresh_from_db()
            
            # إرسال webhook للمتاجر الخارجية الأخرى
            try:
                for other_store in ExternalStore.objects.filter(is_active=True).exclude(id=store.id):
                    try:
                        send_order_webhook(order, other_store)
                    except Exception as webhook_error:
                        print(f"Webhook error for store {other_store.id}: {webhook_error}")
            except Exception as e:
                print(f"Error sending webhooks: {e}")
            
            return Response(
                {
                    'id': order.id,
                    'message': 'تم إنشاء الطلب بنجاح',
                    'updated_balance': str(user_profile.balance),
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'is_finished': order.is_finished,
                    'store_name': store.name,
                },
                status=status.HTTP_201_CREATED
            )
        except Package.DoesNotExist:
            return Response(
                {'error': 'الباقة غير موجودة'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            import traceback
            error_trace = traceback.format_exc()
            print(f"Error in external_order: {e}")
            print(error_trace)
            return Response(
                {'error': f'حدث خطأ أثناء إنشاء الطلب: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    except ExternalStore.DoesNotExist:
            return Response(
                {'error': 'API Key غير صحيح'},
                status=status.HTTP_401_UNAUTHORIZED
            )


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_exchange_rate(request):
    """الحصول على سعر الصرف الحالي"""
    try:
        exchange_rate = ExchangeRate.get_current_rate()
        return Response({
            'rate': float(exchange_rate),
            'currency_from': 'USD',
            'currency_to': 'SYP',
            'message': f'1 USD = {exchange_rate} SYP'
        })
    except Exception as e:
        # في حالة الخطأ، إرجاع القيمة الافتراضية
        return Response({
            'rate': 15000.0,
            'currency_from': 'USD',
            'currency_to': 'SYP',
            'message': '1 USD = 15000.0 SYP (default)'
        })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def check_pin_status(request):
    """التحقق من وجود PIN للمستخدم"""
    try:
        profile = request.user.userprofile
        has_pin = bool(profile.pin and profile.pin.strip())
        return Response({
            'has_pin': has_pin
        })
    except UserProfile.DoesNotExist:
        return Response({
            'has_pin': False
        })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def set_pin(request):
    """تعيين PIN جديد للمستخدم"""
    try:
        pin = request.data.get('pin', '').strip()
        
        if not pin:
            return Response(
                {'error': 'يجب إدخال PIN'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # التحقق من أن PIN يحتوي على 4 أرقام فقط
        if not pin.isdigit() or len(pin) != 4:
            return Response(
                {'error': 'PIN يجب أن يكون 4 أرقام'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        profile = request.user.userprofile
        profile.pin = pin
        profile.save()
        
        return Response({
            'message': 'تم تعيين PIN بنجاح',
            'has_pin': True
        })
    except UserProfile.DoesNotExist:
        return Response(
            {'error': 'ملف المستخدم غير موجود'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def verify_pin(request):
    """التحقق من PIN المستخدم"""
    try:
        pin = request.data.get('pin', '').strip()
        
        if not pin:
            return Response(
                {'error': 'يجب إدخال PIN'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        profile = request.user.userprofile
        
        if not profile.pin or not profile.pin.strip():
            return Response(
                {'error': 'لم يتم تعيين PIN بعد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if profile.pin == pin:
            return Response({
                'verified': True,
                'message': 'PIN صحيح'
            })
        else:
            return Response(
                {'error': 'PIN غير صحيح'},
                status=status.HTTP_401_UNAUTHORIZED
            )
    except UserProfile.DoesNotExist:
        return Response(
            {'error': 'ملف المستخدم غير موجود'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def update_pin(request):
    """تحديث PIN المستخدم (يتطلب PIN القديم)"""
    try:
        old_pin = request.data.get('old_pin', '').strip()
        new_pin = request.data.get('new_pin', '').strip()
        
        if not old_pin or not new_pin:
            return Response(
                {'error': 'يجب إدخال PIN القديم والجديد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # التحقق من أن PIN الجديد يحتوي على 4 أرقام فقط
        if not new_pin.isdigit() or len(new_pin) != 4:
            return Response(
                {'error': 'PIN الجديد يجب أن يكون 4 أرقام'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        profile = request.user.userprofile
        
        if not profile.pin or not profile.pin.strip():
            return Response(
                {'error': 'لم يتم تعيين PIN بعد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # التحقق من PIN القديم
        if profile.pin != old_pin:
            return Response(
                {'error': 'PIN القديم غير صحيح'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # تحديث PIN
        profile.pin = new_pin
        profile.save()
        
        return Response({
            'message': 'تم تحديث PIN بنجاح',
            'has_pin': True
        })
    except UserProfile.DoesNotExist:
        return Response(
            {'error': 'ملف المستخدم غير موجود'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def set_pin(request):
    """إعداد PIN جديد للمستخدم"""
    try:
        pin = request.data.get('pin', '').strip()
        
        # التحقق من صحة PIN
        if not pin:
            return Response(
                {'error': 'يرجى إدخال رمز PIN'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not pin.isdigit():
            return Response(
                {'error': 'رمز PIN يجب أن يحتوي على أرقام فقط'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(pin) < 4 or len(pin) > 6:
            return Response(
                {'error': 'رمز PIN يجب أن يكون بين 4 و 6 أرقام'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # حفظ PIN
        user_profile = request.user.userprofile
        user_profile.pin = pin
        user_profile.save()
        
        return Response({
            'message': 'تم إعداد رمز PIN بنجاح',
            'has_pin': True
        })
    except Exception as e:
        return Response(
            {'error': f'حدث خطأ: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def verify_pin(request):
    """التحقق من PIN"""
    try:
        pin = request.data.get('pin', '').strip()
        
        if not pin:
            return Response(
                {'error': 'يرجى إدخال رمز PIN'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user_profile = request.user.userprofile
        
        if not user_profile.pin:
            return Response(
                {'error': 'لم يتم إعداد رمز PIN بعد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if user_profile.pin == pin:
            return Response({
                'message': 'رمز PIN صحيح',
                'verified': True
            })
        else:
            return Response(
                {'error': 'رمز PIN غير صحيح'},
                status=status.HTTP_401_UNAUTHORIZED
            )
    except Exception as e:
        return Response(
            {'error': f'حدث خطأ: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def update_pin(request):
    """تحديث PIN (يتطلب PIN القديم)"""
    try:
        old_pin = request.data.get('old_pin', '').strip()
        new_pin = request.data.get('new_pin', '').strip()
        
        if not old_pin or not new_pin:
            return Response(
                {'error': 'يرجى إدخال PIN القديم والجديد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # التحقق من صحة PIN الجديد
        if not new_pin.isdigit():
            return Response(
                {'error': 'رمز PIN يجب أن يحتوي على أرقام فقط'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(new_pin) < 4 or len(new_pin) > 6:
            return Response(
                {'error': 'رمز PIN يجب أن يكون بين 4 و 6 أرقام'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user_profile = request.user.userprofile
        
        # التحقق من PIN القديم
        if not user_profile.pin:
            return Response(
                {'error': 'لم يتم إعداد رمز PIN بعد'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if user_profile.pin != old_pin:
            return Response(
                {'error': 'رمز PIN القديم غير صحيح'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # تحديث PIN
        user_profile.pin = new_pin
        user_profile.save()
        
        return Response({
            'message': 'تم تحديث رمز PIN بنجاح',
            'has_pin': True
        })
    except Exception as e:
        return Response(
            {'error': f'حدث خطأ: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def check_pin_status(request):
    """التحقق من وجود PIN"""
    try:
        user_profile = request.user.userprofile
        has_pin = bool(user_profile.pin and user_profile.pin.strip())
        
        return Response({
            'has_pin': has_pin
        })
    except Exception as e:
        return Response(
            {'error': f'حدث خطأ: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )