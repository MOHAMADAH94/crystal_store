# دليل الربط للمتاجر الخارجية - كيفية استخدام API

## 📋 نظرة عامة

نعم، **يمكن لأي متجر الآن استخدام API لإنشاء الطلبات على حسابه في موقعك**، وسيتم:
- ✅ خصم المبلغ من رصيده تلقائياً
- ✅ إنشاء الطلب في النظام
- ✅ إرسال إشعارات (Webhooks) عند تحديث الطلبات

---

## 🚀 الخطوات العملية

### الخطوة 1: إنشاء حساب للمتجر

1. سجل المتجر في موقعك كـ **مستخدم عادي**
2. أضف رصيد لحسابه من لوحة التحكم

### الخطوة 2: إنشاء API Key للمتجر

1. اذهب إلى `/admin/api/apikey/`
2. اضغط "Add API Key"
3. أدخل:
   - **اسم المتجر**: اسم المتجر (مثل "متجر الألعاب")
   - **المستخدم**: اختر حساب المستخدم الذي أنشأته للمتجر
   - **Webhook URL** (اختياري): رابط لإرسال إشعارات الطلبات
4. احفظ - سيتم إنشاء API Key تلقائياً
5. **انسخ API Key** وأعطه للمتجر

### الخطوة 3: المتجر يستخدم API Key

المتجر الآن يمكنه استخدام API Key لإنشاء الطلبات:

```python
import requests

# API Key الذي أعطيته للمتجر
API_KEY = "your_api_key_here"
BASE_URL = "http://your-domain.com"

# إنشاء طلب جديد
response = requests.post(
    f'{BASE_URL}/api/orders/create_order/',
    headers={
        'X-API-Key': API_KEY,
        'Content-Type': 'application/json'
    },
    json={
        'package_id': 1,      # ID الباقة
        'quantity': 5,         # الكمية
        'gamer_id': 'player123' # معرف اللاعب
    }
)

result = response.json()
print(result)
# {
#   "id": 123,
#   "message": "تم إنشاء الطلب بنجاح",
#   "updated_balance": "950.00",
#   "order_date": "2024-01-11T12:00:00Z",
#   "is_finished": true
# }
```

---

## 📝 أمثلة كاملة

### مثال 1: Python

```python
import requests

class ZeroOneAPI:
    def __init__(self, api_key, base_url="http://your-domain.com"):
        self.api_key = api_key
        self.base_url = base_url
        self.headers = {
            'X-API-Key': api_key,
            'Content-Type': 'application/json'
        }
    
    def get_products(self, category_id=None):
        """الحصول على المنتجات"""
        url = f'{self.base_url}/api/products/'
        if category_id:
            url += f'?category={category_id}'
        response = requests.get(url, headers=self.headers)
        return response.json()
    
    def get_packages(self, product_id):
        """الحصول على الباقات"""
        url = f'{self.base_url}/api/packages/?product={product_id}'
        response = requests.get(url, headers=self.headers)
        return response.json()
    
    def create_order(self, package_id, quantity, gamer_id):
        """إنشاء طلب جديد"""
        url = f'{self.base_url}/api/orders/create_order/'
        data = {
            'package_id': package_id,
            'quantity': quantity,
            'gamer_id': gamer_id
        }
        response = requests.post(url, headers=self.headers, json=data)
        return response.json()
    
    def get_balance(self):
        """الحصول على الرصيد الحالي"""
        url = f'{self.base_url}/api/profile/me/'
        response = requests.get(url, headers=self.headers)
        profile = response.json()
        return float(profile['balance'])

# الاستخدام
api = ZeroOneAPI(api_key="your_api_key_here")

# الحصول على المنتجات
products = api.get_products()
print(products)

# الحصول على الباقات
packages = api.get_packages(product_id=1)
print(packages)

# إنشاء طلب
order = api.create_order(
    package_id=1,
    quantity=5,
    gamer_id='player123'
)
print(order)

# التحقق من الرصيد
balance = api.get_balance()
print(f"الرصيد الحالي: {balance}")
```

### مثال 2: JavaScript/Node.js

```javascript
const axios = require('axios');

class ZeroOneAPI {
    constructor(apiKey, baseUrl = 'http://your-domain.com') {
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
        this.headers = {
            'X-API-Key': apiKey,
            'Content-Type': 'application/json'
        };
    }
    
    async getProducts(categoryId = null) {
        let url = `${this.baseUrl}/api/products/`;
        if (categoryId) {
            url += `?category=${categoryId}`;
        }
        const response = await axios.get(url, { headers: this.headers });
        return response.data;
    }
    
    async getPackages(productId) {
        const url = `${this.baseUrl}/api/packages/?product=${productId}`;
        const response = await axios.get(url, { headers: this.headers });
        return response.data;
    }
    
    async createOrder(packageId, quantity, gamerId) {
        const url = `${this.base_url}/api/orders/create_order/`;
        const data = {
            package_id: packageId,
            quantity: quantity,
            gamer_id: gamerId
        };
        const response = await axios.post(url, data, { headers: this.headers });
        return response.data;
    }
    
    async getBalance() {
        const url = `${this.baseUrl}/api/profile/me/`;
        const response = await axios.get(url, { headers: this.headers });
        return parseFloat(response.data.balance);
    }
}

// الاستخدام
const api = new ZeroOneAPI('your_api_key_here');

(async () => {
    try {
        // الحصول على المنتجات
        const products = await api.getProducts();
        console.log(products);
        
        // إنشاء طلب
        const order = await api.createOrder(1, 5, 'player123');
        console.log(order);
        
        // التحقق من الرصيد
        const balance = await api.getBalance();
        console.log(`الرصيد الحالي: ${balance}`);
    } catch (error) {
        console.error('Error:', error.response?.data || error.message);
    }
})();
```

### مثال 3: PHP

```php
<?php
class ZeroOneAPI {
    private $apiKey;
    private $baseUrl;
    
    public function __construct($apiKey, $baseUrl = 'http://your-domain.com') {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
    }
    
    private function request($method, $endpoint, $data = null) {
        $url = $this->baseUrl . $endpoint;
        $ch = curl_init($url);
        
        $headers = [
            'X-API-Key: ' . $this->apiKey,
            'Content-Type: application/json'
        ];
        
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            if ($data) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            }
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        return [
            'code' => $httpCode,
            'data' => json_decode($response, true)
        ];
    }
    
    public function getProducts($categoryId = null) {
        $endpoint = '/api/products/';
        if ($categoryId) {
            $endpoint .= '?category=' . $categoryId;
        }
        return $this->request('GET', $endpoint);
    }
    
    public function getPackages($productId) {
        $endpoint = '/api/packages/?product=' . $productId;
        return $this->request('GET', $endpoint);
    }
    
    public function createOrder($packageId, $quantity, $gamerId) {
        $endpoint = '/api/orders/create_order/';
        $data = [
            'package_id' => $packageId,
            'quantity' => $quantity,
            'gamer_id' => $gamerId
        ];
        return $this->request('POST', $endpoint, $data);
    }
    
    public function getBalance() {
        $result = $this->request('GET', '/api/profile/me/');
        if ($result['code'] === 200) {
            return floatval($result['data']['balance']);
        }
        return null;
    }
}

// الاستخدام
$api = new ZeroOneAPI('your_api_key_here');

// الحصول على المنتجات
$products = $api->getProducts();
print_r($products);

// إنشاء طلب
$order = $api->createOrder(1, 5, 'player123');
print_r($order);

// التحقق من الرصيد
$balance = $api->getBalance();
echo "الرصيد الحالي: " . $balance . "\n";
?>
```

---

## 🔐 الأمان

### أفضل الممارسات:

1. **استخدم HTTPS** في الإنتاج
2. **لا تشارك API Key** مع أي شخص
3. **راقب استخدام API Keys** من لوحة التحكم
4. **عطّل API Keys** غير المستخدمة

### مراقبة الاستخدام:

- اذهب إلى `/admin/api/apikey/`
- ستجد "آخر استخدام" لكل API Key
- يمكنك تعطيل أي API Key من خلال إلغاء تفعيل "نشط"

---

## 📊 كيف يعمل النظام؟

### عند إنشاء طلب:

1. **التحقق من API Key**: النظام يتحقق من صحة API Key
2. **تحديد المستخدم**: يتم ربط الطلب بالمستخدم المرتبط بـ API Key
3. **حساب السعر**: يتم حساب السعر حسب نوع الباقة ومستوى المستخدم
4. **التحقق من الرصيد**: يتم التحقق من وجود رصيد كافي
5. **خصم الرصيد**: يتم خصم المبلغ من رصيد المستخدم تلقائياً
6. **إنشاء الطلب**: يتم إنشاء الطلب في النظام
7. **إرسال Webhook**: يتم إرسال إشعارات للمتاجر الخارجية (إذا تم إعدادها)

### Response عند النجاح:

```json
{
  "id": 123,
  "message": "تم إنشاء الطلب بنجاح",
  "updated_balance": "950.00",
  "order_date": "2024-01-11T12:00:00Z",
  "is_finished": true
}
```

### Response عند الخطأ (رصيد غير كافي):

```json
{
  "error": "الرصيد غير كافي",
  "required_balance": "100.00",
  "available_balance": "50.00",
  "shortage": "50.00"
}
```

---

## 🔔 Webhooks

### إعداد Webhook:

1. عند إنشاء API Key، أدخل **Webhook URL**
2. سيتم إرسال إشعارات عند تحديث الطلبات

### مثال Webhook Payload:

```json
{
  "event": "order_updated",
  "order_id": 123,
  "status": "completed",
  "order_data": {
    "id": 123,
    "user": "store_username",
    "order_date": "2024-01-11T12:00:00Z",
    "is_finished": true,
    "details": [...]
  },
  "timestamp": "2024-01-11T12:00:00Z"
}
```

---

## ❓ الأسئلة الشائعة

### س: هل يمكن للمتجر إنشاء طلبات على حساب مستخدم آخر؟

**ج:** لا، API Key مرتبط بمستخدم محدد. الطلبات تُنشأ دائماً على حساب المستخدم المرتبط بـ API Key.

### س: ماذا يحدث إذا كان الرصيد غير كافي؟

**ج:** سيتم رفض الطلب وإرجاع رسالة خطأ مع تفاصيل الرصيد المطلوب والمتاح.

### س: كيف يمكن للمتجر معرفة رصيده الحالي؟

**ج:** يمكنه استخدام:
```bash
GET /api/profile/me/
Headers: X-API-Key: {api_key}
```

### س: هل يمكن للمتجر إضافة رصيد عبر API؟

**ج:** نعم، يمكنه استخدام:
```bash
POST /api/profile/send_money/
Headers: X-API-Key: {api_key}
Body: {
  "amount": 100,
  "payment_method": 1,
  "receipt": <file>
}
```

---

## 📞 الدعم

للمزيد من المعلومات:
- راجع `API_README.md` للدليل الأساسي
- راجع `/admin/api/` لإدارة API Keys
