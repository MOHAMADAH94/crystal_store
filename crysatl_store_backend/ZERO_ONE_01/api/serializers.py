from rest_framework import serializers
from django.contrib.auth.models import User
from products.models import Category, Product, Package, Agent
from orders.models import Order, OrderDetails
from accounts.models import UserProfile, PaymentMethod, BalanceLog, Notification, UserNotification, Balance_add
from .models import APIKey, ExternalStore


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    balance = serializers.DecimalField(max_digits=10, decimal_places=4, read_only=True)
    first_name = serializers.CharField(source='user.first_name', required=False, allow_blank=True)
    last_name = serializers.CharField(source='user.last_name', required=False, allow_blank=True)
    has_pin = serializers.SerializerMethodField()
    
    class Meta:
        model = UserProfile
        fields = ['id', 'user', 'address', 'address2', 'city', 'state', 'phone', 'balance', 'level', 'first_name', 'last_name', 'currency', 'pin', 'has_pin']
        read_only_fields = ['id', 'balance', 'level', 'has_pin']
        extra_kwargs = {
            'pin': {'write_only': True, 'required': False, 'allow_blank': True, 'allow_null': True}
        }
    
    def get_has_pin(self, obj):
        """إرجاع True إذا كان المستخدم لديه PIN محدد"""
        return bool(obj.pin and obj.pin.strip())
    
    def update(self, instance, validated_data):
        # تحديث بيانات UserProfile
        instance.address = validated_data.get('address', instance.address)
        instance.address2 = validated_data.get('address2', instance.address2)
        instance.city = validated_data.get('city', instance.city)
        instance.state = validated_data.get('state', instance.state)
        instance.phone = validated_data.get('phone', instance.phone)
        
        # تحديث PIN إذا تم إرساله
        if 'pin' in validated_data:
            pin = validated_data.get('pin', '').strip()
            if pin:
                # التحقق من أن PIN يحتوي على 4 أرقام فقط
                if not pin.isdigit() or len(pin) != 4:
                    raise serializers.ValidationError({'pin': 'PIN يجب أن يكون 4 أرقام'})
                instance.pin = pin
            else:
                instance.pin = None
        
        # تحديث بيانات User (first_name, last_name)
        if 'first_name' in validated_data:
            instance.user.first_name = validated_data['first_name']
        if 'last_name' in validated_data:
            instance.user.last_name = validated_data['last_name']
        
        # حفظ التغييرات
        instance.user.save()
        instance.save()
        
        return instance


class CategorySerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    parent_category = serializers.PrimaryKeyRelatedField(read_only=True)
    parent_category_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)
    subcategories = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'name', 'ordering', 'image', 'image_url', 'input_label', 'input_placeholder', 
                  'parent_category', 'parent_category_id', 'subcategories']
    
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None
    
    def get_subcategories(self, obj):
        """إرجاع الفئات الفرعية"""
        subcategories = obj.subcategories.all()
        return CategorySerializer(subcategories, many=True, context=self.context).data


class ProductSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(queryset=Category.objects.all(), source='category', write_only=True)
    image_url = serializers.SerializerMethodField()
    packages_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Product
        fields = ['id', 'category', 'category_id', 'name', 'description', 'coins_price', 
                  'image', 'image_url', 'is_active', 'created_at', 'packages_count',
                  'min_custom_quantity', 'max_custom_quantity', 'allow_decimal_qty']
        read_only_fields = ['id', 'created_at']
    
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None
    
    def get_packages_count(self, obj):
        return obj.packages.filter(is_active=True).count()


class PackageSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(queryset=Product.objects.all(), source='product', write_only=True)
    image_url = serializers.SerializerMethodField()
    calculated_price = serializers.SerializerMethodField()
    
    class Meta:
        model = Package
        fields = ['id', 'product', 'product_id', 'name', 'description', 'quantity', 
                  'price', 'image', 'image_url', 'is_active', 'is_custom', 
                  'denomination_id', 'calculated_price']
        read_only_fields = ['id']
    
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None
    
    def get_calculated_price(self, obj):
        return float(obj.calculate_custom_price())


class AgentSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Agent
        fields = ['id', 'name', 'address', 'image', 'image_url', 'contact_info', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']
    
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class OrderDetailsSerializer(serializers.ModelSerializer):
    package = PackageSerializer(source='Package', read_only=True)
    package_id = serializers.PrimaryKeyRelatedField(queryset=Package.objects.all(), source='Package', write_only=True)
    
    class Meta:
        model = OrderDetails
        fields = ['id', 'package', 'package_id', 'price', 'final_price', 'gamer_id', 
                  'quantity', 'status', 'response']
        read_only_fields = ['id', 'price', 'final_price']


class OrderSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    details = OrderDetailsSerializer(source='orderdetails_set', many=True, read_only=True)
    
    class Meta:
        model = Order
        fields = ['id', 'user', 'order_date', 'is_finished', 'details']
        read_only_fields = ['id', 'order_date']


class CreateOrderSerializer(serializers.Serializer):
    """Serializer لإنشاء طلب جديد"""
    from decimal import Decimal
    package_id = serializers.IntegerField()
    quantity = serializers.DecimalField(max_digits=10, decimal_places=4, min_value=Decimal('0.0001'), required=False, allow_null=True)
    gamer_id = serializers.CharField(max_length=225)
    custom_quantity = serializers.DecimalField(max_digits=10, decimal_places=4, min_value=Decimal('0.0001'), required=False, allow_null=True)
    
    def validate_gamer_id(self, value):
        """التحقق من أن gamer_id يحتوي على الأرقام والحروف الإنجليزية والرموز فقط"""
        import re
        # السماح بالأرقام (0-9)، الحروف الإنجليزية (a-z, A-Z)، والرموز الشائعة (@, ., _, -, +)
        # هذا يسمح بإدخال الإيميل أيضاً
        pattern = r'^[a-zA-Z0-9@._\-+]+$'
        if not re.match(pattern, value):
            raise serializers.ValidationError(
                "معرف اللاعب يجب أن يحتوي على الأرقام والحروف الإنجليزية والرموز فقط (@, ., _, -, +)"
            )
        return value
    
    def validate(self, data):
        package = Package.objects.get(id=data['package_id'])
        product = package.product
        
        # تحديد الكمية المستخدمة
        if package.is_custom:
            if not data.get('custom_quantity'):
                raise serializers.ValidationError("يجب تحديد الكمية للباقة المخصصة")
            quantity = data['custom_quantity']
        else:
            if not data.get('quantity'):
                raise serializers.ValidationError("يجب تحديد الكمية")
            quantity = data['quantity']
        
        # التحقق من السماح بالكمية العشرية
        if not product.allow_decimal_qty:
            # إذا لم يكن المنتج يسمح بالكمية العشرية، يجب أن تكون الكمية عدد صحيح
            if isinstance(quantity, (int, float)) and quantity != int(quantity):
                raise serializers.ValidationError(
                    "هذا المنتج لا يسمح بالكمية العشرية. يجب إدخال عدد صحيح"
                )
            # تحويل إلى عدد صحيح
            quantity = int(quantity)
        
        # التحقق من الحد الأدنى والأقصى للكمية (للباقات المخصصة)
        if package.is_custom:
            if product.min_custom_quantity and quantity < product.min_custom_quantity:
                raise serializers.ValidationError(
                    f"الكمية يجب أن تكون على الأقل {product.min_custom_quantity}"
                )
            if product.max_custom_quantity and quantity > product.max_custom_quantity:
                raise serializers.ValidationError(
                    f"الكمية يجب أن تكون على الأكثر {product.max_custom_quantity}"
                )
        
        # حفظ الكمية في data
        if package.is_custom:
            data['quantity'] = quantity
        else:
            data['quantity'] = quantity
        
        return data


class PaymentMethodSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = PaymentMethod
        fields = ['id', 'name', 'image', 'image_url', 'address', 'details', 'discount_percentage']
    
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class BalanceLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = BalanceLog
        fields = ['id', 'old_balance', 'new_balance', 'change_date', 'description']
        read_only_fields = ['id', 'change_date']


class BalanceAddSerializer(serializers.ModelSerializer):
    payment_method = PaymentMethodSerializer(read_only=True)
    receipt_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Balance_add
        fields = ['id', 'amount', 'receipt', 'receipt_url', 'is_processed', 'created_at', 'payment_method']
        read_only_fields = ['id', 'created_at']
    
    def get_receipt_url(self, obj):
        if obj.receipt:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.receipt.url)
            return obj.receipt.url
        return None


class NotificationSerializer(serializers.ModelSerializer):
    is_read = serializers.SerializerMethodField()
    
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'created_at', 'is_read']
        read_only_fields = ['id', 'created_at']
    
    def get_is_read(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                user_notification = UserNotification.objects.get(
                    user=request.user, 
                    notification=obj
                )
                return user_notification.read
            except UserNotification.DoesNotExist:
                return False
        return False


class APIKeySerializer(serializers.ModelSerializer):
    class Meta:
        model = APIKey
        fields = ['id', 'name', 'key', 'is_active', 'created_at', 'last_used', 'webhook_url']
        read_only_fields = ['id', 'key', 'created_at', 'last_used']


class ExternalStoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExternalStore
        fields = ['id', 'name', 'api_key', 'base_url', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']



