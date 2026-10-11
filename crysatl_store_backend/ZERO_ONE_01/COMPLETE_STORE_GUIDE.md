# دليل شامل: كيف يعمل أي متجر مع موقعك

## ✅ نعم، الآن يستطيع أي متجر العمل معك!

يمكن لأي متجر الآن:
1. ✅ **التسجيل** في موقعك
2. ✅ **الحصول على API Key** تلقائياً
3. ✅ **إنشاء الطلبات** على حسابه
4. ✅ **خصم الرصيد** من حسابه تلقائياً
5. ✅ **معالجة الطلبات** بشكل كامل

---

## 🚀 الخطوات الكاملة للمتجر

### الخطوة 1: التسجيل

المتجر يسجل حساب جديد في موقعك:

```python
import requests

# التسجيل
response = requests.post(
    'http://your-domain.com/api/auth/register/',
    json={
        'username': 'store_name',
        'email': 'store@example.com',
        'password': 'secure_password'
    }
)

result = response.json()
print(result)
# {
#   "token": "abc123...",
#   "user": {
#     "id": 1,
#     "username": "store_name",
#     "email": "store@example.com"
#   }
# }

TOKEN = result['token']
```

### الخطوة 2: إضافة رصيد (من لوحة التحكم)

**أنت** تضيف رصيد لحساب المتجر من لوحة التحكم:
- اذهب إلى `/admin/accounts/userprofile/`
- ابحث عن المستخدم
- أضف رصيد لحسابه

### الخطوة 3: إنشاء API Key

المتجر ينشئ API Key لحسابه:

```python
# استخدام Token الذي حصل عليه من التسجيل
response = requests.post(
    'http://your-domain.com/api/api-keys/',
    headers={
        'Authorization': f'Token {TOKEN}',
        'Content-Type': 'application/json'
    },
    json={
        'name': 'My Store API Key'
    }
)

result = response.json()
print(result)
# {
#   "id": 1,
#   "name": "My Store API Key",
#   "key": "generated_api_key_here...",
#   "is_active": true,
#   "created_at": "2024-01-11T12:00:00Z"
# }

API_KEY = result['key']
```

### الخطوة 4: استخدام API Key لإنشاء الطلبات

الآن المتجر يستخدم API Key لإنشاء الطلبات:

```python
# الحصول على المنتجات
products = requests.get(
    'http://your-domain.com/api/products/',
    headers={'X-API-Key': API_KEY}
).json()

print(products)

# الحصول على الباقات
packages = requests.get(
    'http://your-domain.com/api/packages/?product=1',
    headers={'X-API-Key': API_KEY}
).json()

print(packages)

# إنشاء طلب جديد
order = requests.post(
    'http://your-domain.com/api/orders/create_order/',
    headers={
        'X-API-Key': API_KEY,
        'Content-Type': 'application/json'
    },
    json={
        'package_id': 1,
        'quantity': 5,
        'gamer_id': 'player123'
    }
).json()

print(order)
# {
#   "id": 123,
#   "message": "تم إنشاء الطلب بنجاح",
#   "updated_balance": "950.00",  # الرصيد بعد الخصم
#   "order_date": "2024-01-11T12:00:00Z",
#   "is_finished": true
# }
```

---

## 📋 مثال كامل (Python)

```python
import requests

class ZeroOneStore:
    def __init__(self, base_url='http://your-domain.com'):
        self.base_url = base_url
        self.token = None
        self.api_key = None
    
    def register(self, username, email, password):
        """التسجيل"""
        response = requests.post(
            f'{self.base_url}/api/auth/register/',
            json={
                'username': username,
                'email': email,
                'password': password
            }
        )
        if response.status_code == 201:
            data = response.json()
            self.token = data['token']
            return data
        else:
            raise Exception(f"Registration failed: {response.json()}")
    
    def login(self, username, password):
        """تسجيل الدخول"""
        response = requests.post(
            f'{self.base_url}/api/auth/login/',
            json={
                'username': username,
                'password': password
            }
        )
        if response.status_code == 200:
            data = response.json()
            self.token = data['token']
            return data
        else:
            raise Exception(f"Login failed: {response.json()}")
    
    def create_api_key(self, name='My Store API Key'):
        """إنشاء API Key"""
        if not self.token:
            raise Exception("You must login or register first")
        
        response = requests.post(
            f'{self.base_url}/api/api-keys/',
            headers={
                'Authorization': f'Token {self.token}',
                'Content-Type': 'application/json'
            },
            json={'name': name}
        )
        if response.status_code == 201:
            data = response.json()
            self.api_key = data['key']
            return data
        else:
            raise Exception(f"API Key creation failed: {response.json()}")
    
    def get_products(self, category_id=None):
        """الحصول على المنتجات"""
        url = f'{self.base_url}/api/products/'
        if category_id:
            url += f'?category={category_id}'
        
        headers = {}
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        elif self.token:
            headers['Authorization'] = f'Token {self.token}'
        
        response = requests.get(url, headers=headers)
        return response.json()
    
    def get_packages(self, product_id):
        """الحصول على الباقات"""
        url = f'{self.base_url}/api/packages/?product={product_id}'
        
        headers = {}
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        elif self.token:
            headers['Authorization'] = f'Token {self.token}'
        
        response = requests.get(url, headers=headers)
        return response.json()
    
    def create_order(self, package_id, quantity, gamer_id):
        """إنشاء طلب جديد"""
        if not self.api_key and not self.token:
            raise Exception("You must have API Key or Token")
        
        url = f'{self.base_url}/api/orders/create_order/'
        headers = {'Content-Type': 'application/json'}
        
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        elif self.token:
            headers['Authorization'] = f'Token {self.token}'
        
        response = requests.post(
            url,
            headers=headers,
            json={
                'package_id': package_id,
                'quantity': quantity,
                'gamer_id': gamer_id
            }
        )
        return response.json()
    
    def get_balance(self):
        """الحصول على الرصيد الحالي"""
        if not self.api_key and not self.token:
            raise Exception("You must have API Key or Token")
        
        url = f'{self.base_url}/api/profile/me/'
        headers = {}
        
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        elif self.token:
            headers['Authorization'] = f'Token {self.token}'
        
        response = requests.get(url, headers=headers)
        profile = response.json()
        return float(profile['balance'])

# الاستخدام
store = ZeroOneStore('http://your-domain.com')

# 1. التسجيل
store.register('my_store', 'store@example.com', 'password123')
print("✅ تم التسجيل")

# 2. إنشاء API Key
api_key_data = store.create_api_key('My Store API Key')
print(f"✅ تم إنشاء API Key: {api_key_data['key']}")

# 3. الحصول على المنتجات
products = store.get_products()
print(f"✅ المنتجات: {len(products)} منتج")

# 4. إنشاء طلب
order = store.create_order(
    package_id=1,
    quantity=5,
    gamer_id='player123'
)
print(f"✅ تم إنشاء الطلب: {order['id']}")
print(f"✅ الرصيد الجديد: {order['updated_balance']}")

# 5. التحقق من الرصيد
balance = store.get_balance()
print(f"✅ الرصيد الحالي: {balance}")
```

---

## 🔄 سير العمل الكامل

```
1. المتجر يسجل حساب جديد
   ↓
2. أنت تضيف رصيد لحسابه (من لوحة التحكم)
   ↓
3. المتجر يسجل الدخول
   ↓
4. المتجر ينشئ API Key
   ↓
5. المتجر يستخدم API Key لإنشاء الطلبات
   ↓
6. يتم خصم المبلغ من رصيده تلقائياً
   ↓
7. يتم معالجة الطلب
```

---

## 📊 Endpoints المتاحة

### 1. التسجيل
```bash
POST /api/auth/register/
Body: {
  "username": "string",
  "email": "string",
  "password": "string"
}
Response: {
  "token": "string",
  "user": {...}
}
```

### 2. تسجيل الدخول
```bash
POST /api/auth/login/
Body: {
  "username": "string",
  "password": "string"
}
Response: {
  "token": "string",
  "user": {...}
}
```

### 3. إنشاء API Key
```bash
POST /api/api-keys/
Headers: Authorization: Token {token}
Body: {
  "name": "string"
}
Response: {
  "id": 1,
  "name": "string",
  "key": "generated_key",
  "is_active": true
}
```

### 4. إنشاء طلب
```bash
POST /api/orders/create_order/
Headers: X-API-Key: {api_key}
# أو
Headers: Authorization: Token {token}
Body: {
  "package_id": 1,
  "quantity": 5,
  "gamer_id": "string"
}
Response: {
  "id": 123,
  "message": "تم إنشاء الطلب بنجاح",
  "updated_balance": "950.00",
  "order_date": "2024-01-11T12:00:00Z",
  "is_finished": true
}
```

### 5. الحصول على الرصيد
```bash
GET /api/profile/me/
Headers: X-API-Key: {api_key}
# أو
Headers: Authorization: Token {token}
Response: {
  "id": 1,
  "user": {...},
  "balance": "1000.00",
  "level": "vip1",
  ...
}
```

---

## ⚠️ ملاحظات مهمة

### 1. الرصيد
- **يجب أن يكون لدى المتجر رصيد كافي** قبل إنشاء الطلبات
- يمكنك إضافة الرصيد من لوحة التحكم: `/admin/accounts/userprofile/`

### 2. API Key
- **كل متجر يمكنه إنشاء عدة API Keys**
- يمكن تعطيل أي API Key من لوحة التحكم
- API Key مرتبط بحساب المستخدم الذي أنشأه

### 3. الأمان
- **استخدم HTTPS** في الإنتاج
- **لا تشارك API Keys** مع أي شخص
- **راقب استخدام API Keys** من لوحة التحكم

---

## 🎯 الخلاصة

**نعم، النظام جاهز بالكامل!**

أي متجر يمكنه:
1. ✅ التسجيل في موقعك
2. ✅ الحصول على API Key
3. ✅ إنشاء الطلبات على حسابه
4. ✅ خصم الرصيد من حسابه تلقائياً
5. ✅ معالجة الطلبات بشكل كامل

**كل شيء يعمل تلقائياً!** 🚀

---

## 📞 الدعم

للمزيد من المعلومات:
- راجع `API_README.md` للدليل الأساسي
- راجع `API_STORE_GUIDE.md` للدليل الشامل
- راجع `/admin/api/` لإدارة API Keys
