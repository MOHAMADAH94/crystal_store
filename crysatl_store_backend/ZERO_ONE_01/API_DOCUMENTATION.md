# API Documentation
# وثائق API

## Base URL
```
https://www.crystal4card.com/api
```

## Authentication
## المصادقة

The API supports two authentication methods:
يدعم API طريقتين للمصادقة:

### 1. Token Authentication
### 1. مصادقة Token

**How to Get a Token:**
**كيفية الحصول على Token:**

1. **Register a new account** using `/auth/register/` endpoint
2. **Or login** using `/auth/login/` endpoint
3. You will receive a `token` in the response
4. Include it in the `Authorization` header for authenticated requests

1. **سجل حساب جديد** باستخدام endpoint `/auth/register/`
2. **أو سجل الدخول** باستخدام endpoint `/auth/login/`
3. ستحصل على `token` في الاستجابة
4. قم بإضافته في header `Authorization` للطلبات التي تتطلب مصادقة

**Usage:**
**الاستخدام:**

```
Authorization: Token <your_token_here>
```

**Example:**
**مثال:**

```bash
curl -X GET https://www.crystal4card.com/api/orders/ \
  -H "Authorization: Token abc123def456..."
```

---

### 2. API Key Authentication
### 2. مصادقة API Key

**How to Get an API Key:**
**كيفية الحصول على API Key:**

**Option 1: Through Admin Panel (For Account Owner)**
**الخيار 1: من خلال لوحة التحكم (لصاحب الحساب)**

If you have admin access to your account:
إذا كان لديك وصول إداري لحسابك:

1. Login to the admin panel: `https://www.crystal4card.com/admin/`
2. Go to **API Keys** section
3. Click **Add API Key**
4. Enter a name for your API key (e.g., "My Website Integration")
5. The API key will be automatically generated
6. Copy the API key and save it securely (you won't be able to see it again)

1. سجل الدخول إلى لوحة التحكم: `https://www.crystal4card.com/admin/`
2. اذهب إلى قسم **API Keys**
3. اضغط **Add API Key**
4. أدخل اسماً لمفتاح API (مثلاً: "تكامل موقعي")
5. سيتم إنشاء مفتاح API تلقائياً
6. انسخ مفتاح API واحفظه بشكل آمن (لن تتمكن من رؤيته مرة أخرى)

**Option 1b: Request from Administrator**
**الخيار 1ب: طلب من المسؤول**

If you don't have admin access, contact the administrator to create an API Key for you:
إذا لم يكن لديك وصول إداري، اتصل بالمسؤول لإنشاء API Key لك:

1. Contact the administrator with your account details
2. Request an API Key for your integration
3. The administrator will create the API Key and provide it to you
4. Save the API Key securely

1. اتصل بالمسؤول مع تفاصيل حسابك
2. اطلب API Key للتكامل الخاص بك
3. سيقوم المسؤول بإنشاء API Key وتزويدك به
4. احفظ API Key بشكل آمن

**Option 2: Through API (If you have a token)**
**الخيار 2: من خلال API (إذا كان لديك token)**

**Create API Key:**
**إنشاء API Key:**

**POST** `/api-keys/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "name": "My Website Integration",
  "webhook_url": "https://example.com/webhook" // optional
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "name": "My Website Integration",
  "key": "abc123def456ghi789...",
  "is_active": true,
  "created_at": "2026-02-07T10:30:00Z",
  "last_used": null,
  "webhook_url": "https://example.com/webhook"
}
```

**⚠️ Important:** Save the `key` value immediately - you won't be able to see it again!
**⚠️ مهم:** احفظ قيمة `key` فوراً - لن تتمكن من رؤيتها مرة أخرى!

**Get Your API Keys:**
**الحصول على مفاتيح API الخاصة بك:**

**GET** `/api-keys/`

**Authentication Required:** Token

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "My Website Integration",
    "key": "abc123def456...", // Only shown when created
    "is_active": true,
    "created_at": "2026-02-07T10:30:00Z",
    "last_used": "2026-02-07T15:30:00Z",
    "webhook_url": "https://example.com/webhook"
  }
]
```

**Usage:**
**الاستخدام:**

```
X-API-Key: <your_api_key_here>
```

**Example:**
**مثال:**

```bash
curl -X POST https://www.crystal4card.com/api/external/order/ \
  -H "X-API-Key: abc123def456ghi789..." \
  -H "Content-Type: application/json" \
  -d '{
    "package_id": 1,
    "quantity": 1.0,
    "gamer_id": "player123"
  }'
```

**Note:** API Keys are linked to your user account. Orders created with an API Key will be charged to your account balance.
**ملاحظة:** مفاتيح API مرتبطة بحسابك. الطلبات التي يتم إنشاؤها باستخدام API Key سيتم خصمها من رصيد حسابك.

---

## Endpoints
## النقاط النهائية

### Authentication Endpoints
### نقاط المصادقة

#### 1. Register
#### 1. التسجيل

**POST** `/auth/register/`

**Request Body:**
```json
{
  "username": "string",
  "email": "string",
  "password": "string"
}
```

**Response (201 Created):**
```json
{
  "token": "string",
  "user": {
    "id": 1,
    "username": "string",
    "email": "string",
    "first_name": "",
    "last_name": ""
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "اسم المستخدم موجود بالفعل"
}
```

---

#### 2. Login
#### 2. تسجيل الدخول

**POST** `/auth/login/`

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200 OK):**
```json
{
  "token": "string",
  "user": {
    "id": 1,
    "username": "string",
    "email": "string",
    "first_name": "",
    "last_name": ""
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "بيانات الدخول غير صحيحة"
}
```

---

### Categories
### الفئات

#### Get All Categories
#### الحصول على جميع الفئات

**GET** `/categories/`

**Query Parameters:**
- `parent_only` (optional): `true` to get only parent categories
- `parent_only` (اختياري): `true` للحصول على الفئات الأساسية فقط

**Response (200 OK):**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "string",
      "description": "string",
      "image": "https://example.com/image.jpg",
      "ordering": 1,
      "parent_category": null,
      "subcategories": []
    }
  ]
}
```

---

### Products
### المنتجات

#### Get All Products
#### الحصول على جميع المنتجات

**GET** `/products/`

**Query Parameters:**
- `category` (optional): Filter by category ID
- `category` (اختياري): تصفية حسب معرف الفئة

**Response (200 OK):**
```json
{
  "count": 20,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "string",
      "description": "string",
      "category": {
        "id": 1,
        "name": "string"
      },
      "image": "https://example.com/image.jpg",
      "is_active": true,
      "allow_decimal_qty": false,
      "coins_price": "10.0000",
      "min_custom_quantity": 1,
      "max_custom_quantity": 1000
    }
  ]
}
```

---

### Packages
### الباقات

#### Get All Packages
#### الحصول على جميع الباقات

**GET** `/packages/`

**Query Parameters:**
- `product` (optional): Filter by product ID
- `product` (اختياري): تصفية حسب معرف المنتج

**Response (200 OK):**
```json
{
  "count": 50,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "string",
      "product": {
        "id": 1,
        "name": "string"
      },
      "price": "10.0000",
      "quantity": 100,
      "is_custom": false,
      "is_active": true,
      "calculated_price": "10.0000",
      "denomination_id": 123
    }
  ]
}
```

---

### Orders
### الطلبات

#### Create Order
#### إنشاء طلب

**POST** `/orders/create_order/`

**Authentication Required:** Token or API Key

**Request Body:**
```json
{
  "package_id": 1,
  "quantity": 1.0,
  "gamer_id": "player123",
  "custom_quantity": 1.0
}
```

**Field Descriptions:**
- `package_id` (required): Package ID
- `quantity` (required): Quantity (supports decimal if `allow_decimal_qty` is true)
- `gamer_id` (required): Player/User ID for the game
- `custom_quantity` (optional): Custom quantity for custom packages

**Response (201 Created):**
```json
{
  "id": 123,
  "message": "تم إنشاء الطلب بنجاح",
  "updated_balance": "100.0000",
  "order_date": "2026-02-07T10:30:00Z",
  "is_finished": true
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "الرصيد غير كافي",
  "required_balance": "10.0000",
  "available_balance": "5.0000",
  "shortage": "5.0000"
}
```

**Error Response (400 Bad Request - Validation):**
```json
{
  "package_id": ["This field is required."],
  "quantity": ["This field is required."],
  "gamer_id": ["This field is required."]
}
```

---

#### Get Orders
#### الحصول على الطلبات

**GET** `/orders/`

**Authentication Required:** Token or API Key

**Response (200 OK):**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 123,
      "user": {
        "id": 1,
        "username": "string",
        "email": "string",
        "first_name": "",
        "last_name": ""
      },
      "order_date": "2026-02-07T10:30:00Z",
      "is_finished": true,
      "details": [
        {
          "id": 456,
          "package": {
            "id": 1,
            "name": "string",
            "product": {
              "id": 1,
              "name": "string"
            }
          },
          "price": "10.0000",
          "final_price": "10.1000",
          "gamer_id": "player123",
          "quantity": "1.0000",
          "status": "done",
          "response": "ملاحظات الطلب من API"
        }
      ]
    }
  ]
}
```

**Note:** Orders are automatically filtered by the authenticated user. Status is automatically updated when fetching orders.
**ملاحظة:** يتم تصفية الطلبات تلقائياً حسب المستخدم المصادق عليه. يتم تحديث الحالة تلقائياً عند جلب الطلبات.

**Order Status Values:**
- `pending`: قيد المعالجة
- `done`: مكتمل
- `rejected`: مرفوض

---

### Profile
### الملف الشخصي

#### Get Profile
#### الحصول على الملف الشخصي

**GET** `/profile/me/`

**Authentication Required:** Token

**Response (200 OK):**
```json
{
  "id": 1,
  "user": {
    "id": 1,
    "username": "string",
    "email": "string",
    "first_name": "",
    "last_name": ""
  },
  "address": "string",
  "address2": "string",
  "city": "string",
  "state": "string",
  "phone": "string",
  "balance": "100.0000",
  "level": 1,
  "currency": "USD",
  "has_pin": false
}
```

---

#### Update Profile
#### تحديث الملف الشخصي

**PATCH** `/profile/update_profile/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "address": "string",
  "address2": "string",
  "city": "string",
  "state": "string",
  "phone": "string",
  "first_name": "string",
  "last_name": "string"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "user": {
    "id": 1,
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string"
  },
  "address": "string",
  "balance": "100.0000",
  "level": 1
}
```

---

#### Get Balance History
#### الحصول على سجل الرصيد

**GET** `/profile/balance_history/`

**Authentication Required:** Token

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "old_balance": "100.0000",
    "new_balance": "90.0000",
    "description": "طلب #123",
    "created_at": "2026-02-07T10:30:00Z"
  }
]
```

---

#### Send Money (Add Balance)
#### إرسال المال (إضافة رصيد)

**POST** `/profile/send_money/`

**Authentication Required:** Token

**Request Body (Form Data):**
```
amount: 100.0
payment_method: 1
receipt: <file>
```

**Response (201 Created):**
```json
{
  "id": 1,
  "amount": "100.0000",
  "status": "pending",
  "message": "تم إرسال الطلب بنجاح"
}
```

---

### Payment Methods
### طرق الدفع

#### Get Payment Methods
#### الحصول على طرق الدفع

**GET** `/payment-methods/`

**Response (200 OK):**
```json
{
  "count": 5,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "string",
      "description": "string",
      "is_active": true
    }
  ]
}
```

---

### Notifications
### الإشعارات

#### Get Notifications
#### الحصول على الإشعارات

**GET** `/notifications/`

**Authentication Required:** Token

**Response (200 OK):**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "title": "string",
      "message": "string",
      "is_read": false,
      "created_at": "2026-02-07T10:30:00Z"
    }
  ]
}
```

---

#### Mark Notification as Read
#### تحديد الإشعار كمقروء

**POST** `/notifications/{id}/mark_read/`

**Authentication Required:** Token

**Response (200 OK):**
```json
{
  "message": "تم تحديد الإشعار كمقروء"
}
```

---

### Exchange Rate
### سعر الصرف

#### Get Exchange Rate
#### الحصول على سعر الصرف

**GET** `/exchange-rate/`

**Response (200 OK):**
```json
{
  "rate": 15000.0,
  "currency_from": "USD",
  "currency_to": "SYP",
  "message": "1 USD = 15000.0 SYP"
}
```

---

### PIN Management
### إدارة PIN

#### Check PIN Status
#### التحقق من حالة PIN

**GET** `/pin/check/`

**Authentication Required:** Token

**Response (200 OK):**
```json
{
  "has_pin": true
}
```

---

#### Set PIN
#### تعيين PIN

**POST** `/pin/set/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "pin": "1234"
}
```

**Response (200 OK):**
```json
{
  "message": "تم تعيين PIN بنجاح",
  "has_pin": true
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "PIN يجب أن يكون 4 أرقام"
}
```

---

#### Verify PIN
#### التحقق من PIN

**POST** `/pin/verify/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "pin": "1234"
}
```

**Response (200 OK):**
```json
{
  "verified": true
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "PIN غير صحيح"
}
```

---

#### Update PIN
#### تحديث PIN

**POST** `/pin/update/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "old_pin": "1234",
  "new_pin": "5678"
}
```

**Response (200 OK):**
```json
{
  "message": "تم تحديث PIN بنجاح"
}
```

---

### API Keys Management
### إدارة مفاتيح API

#### Create API Key
#### إنشاء API Key

**POST** `/api-keys/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "name": "My Website Integration",
  "webhook_url": "https://example.com/webhook"
}
```

**Field Descriptions:**
- `name` (required): Name/description for the API key
- `webhook_url` (optional): Webhook URL to receive order updates

**Response (201 Created):**
```json
{
  "id": 1,
  "name": "My Website Integration",
  "key": "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz",
  "is_active": true,
  "created_at": "2026-02-07T10:30:00Z",
  "last_used": null,
  "webhook_url": "https://example.com/webhook"
}
```

**⚠️ Important:** Save the `key` value immediately - you won't be able to see it again after creation!
**⚠️ مهم:** احفظ قيمة `key` فوراً - لن تتمكن من رؤيتها مرة أخرى بعد الإنشاء!

---

#### Get API Keys
#### الحصول على مفاتيح API

**GET** `/api-keys/`

**Authentication Required:** Token

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "My Website Integration",
    "key": "abc123def456...", // Only shown when created
    "is_active": true,
    "created_at": "2026-02-07T10:30:00Z",
    "last_used": "2026-02-07T15:30:00Z",
    "webhook_url": "https://example.com/webhook"
  }
]
```

**Note:** The full `key` is only shown when creating a new API key. After that, only a partial key is shown for security.
**ملاحظة:** يتم عرض `key` الكامل فقط عند إنشاء API key جديد. بعد ذلك، يتم عرض جزء من المفتاح فقط لأسباب أمنية.

---

#### Update API Key
#### تحديث API Key

**PATCH** `/api-keys/{id}/`

**Authentication Required:** Token

**Request Body:**
```json
{
  "name": "Updated Name",
  "is_active": true,
  "webhook_url": "https://new-webhook-url.com/webhook"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "name": "Updated Name",
  "key": "abc123def456...",
  "is_active": true,
  "created_at": "2026-02-07T10:30:00Z",
  "last_used": "2026-02-07T15:30:00Z",
  "webhook_url": "https://new-webhook-url.com/webhook"
}
```

---

#### Delete API Key
#### حذف API Key

**DELETE** `/api-keys/{id}/`

**Authentication Required:** Token

**Response (204 No Content)**

---

### External Order (API Key)
### طلب خارجي (API Key)

#### Create External Order
#### إنشاء طلب خارجي

**POST** `/external/order/`

**Authentication Required:** API Key (X-API-Key header)

**Headers:**
```
X-API-Key: <your_api_key>
```

**Request Body:**
```json
{
  "package_id": 1,
  "quantity": 1.0,
  "gamer_id": "player123",
  "custom_quantity": 1.0
}
```

**Response (201 Created):**
```json
{
  "id": 123,
  "message": "تم إنشاء الطلب بنجاح",
  "updated_balance": "100.0000",
  "order_date": "2026-02-07T10:30:00Z",
  "is_finished": true,
  "store_name": "External Store Name"
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "API Key مطلوب"
}
```

---

### Agents
### الوكلاء

#### Get Agents
#### الحصول على الوكلاء

**GET** `/agents/`

**Response (200 OK):**
```json
{
  "count": 5,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "string",
      "description": "string",
      "image": "https://example.com/image.jpg",
      "is_active": true
    }
  ]
}
```

---

## Error Handling
## معالجة الأخطاء

All error responses follow this format:
جميع استجابات الأخطاء تتبع هذا التنسيق:

```json
{
  "error": "Error message in Arabic"
}
```

**Common HTTP Status Codes:**
- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Authentication required or invalid
- `403 Forbidden`: Permission denied
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

---

## Order Status Flow
## تدفق حالة الطلب

1. **Order Created**: Order is created with status `pending`
2. **Sent to Provider**: Order is sent to external provider (SW-Games API)
3. **Status Updated**: Status is automatically updated based on provider response:
   - `done`: Order completed successfully
   - `rejected`: Order was rejected
   - `pending`: Order is still processing

**Note:** When fetching orders via `GET /orders/`, the status is automatically updated from the provider API.
**ملاحظة:** عند جلب الطلبات عبر `GET /orders/`، يتم تحديث الحالة تلقائياً من API المزود.

---

## Rate Limiting
## تحديد المعدل

Currently, there is no rate limiting. However, please use the API responsibly.
حالياً، لا يوجد تحديد للمعدل. ومع ذلك، يرجى استخدام API بمسؤولية.

---

## Support
## الدعم

For API support, please contact the administrator.
لدعم API، يرجى الاتصال بالمسؤول.

---

## Version
## الإصدار

**API Version:** 1.0
**Last Updated:** 2026-02-07

---

## Examples
## أمثلة

### Example: Create Order (cURL)
### مثال: إنشاء طلب (cURL)

```bash
curl -X POST https://www.crystal4card.com/api/orders/create_order/ \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "package_id": 1,
    "quantity": 1.0,
    "gamer_id": "player123"
  }'
```

### Example: Get Orders (JavaScript)
### مثال: الحصول على الطلبات (JavaScript)

```javascript
fetch('https://www.crystal4card.com/api/orders/', {
  headers: {
    'Authorization': 'Token YOUR_TOKEN_HERE'
  }
})
.then(response => response.json())
.then(data => console.log(data));
```

### Example: Create Order (Python)
### مثال: إنشاء طلب (Python)

```python
import requests

url = "https://www.crystal4card.com/api/orders/create_order/"
headers = {
    "Authorization": "Token YOUR_TOKEN_HERE",
    "Content-Type": "application/json"
}
data = {
    "package_id": 1,
    "quantity": 1.0,
    "gamer_id": "player123"
}

response = requests.post(url, json=data, headers=headers)
print(response.json())
```

---

## Notes
## ملاحظات

1. All prices are in USD by default. For SYP currency, conversion is handled automatically.
2. Decimal quantities are supported for products with `allow_decimal_qty: true`.
3. Order status is automatically synchronized with the provider API.
4. All timestamps are in ISO 8601 format (UTC).

1. جميع الأسعار بالدولار الأمريكي افتراضياً. للعملة السورية، يتم التحويل تلقائياً.
2. الكميات العشرية مدعومة للمنتجات التي لديها `allow_decimal_qty: true`.
3. حالة الطلب متزامنة تلقائياً مع API المزود.
4. جميع الطوابع الزمنية بتنسيق ISO 8601 (UTC).
