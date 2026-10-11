# from django import template
# from django.conf import settings
# from decimal import Decimal, ROUND_DOWN

# register = template.Library()

# @register.filter
# def discounted_price(package, user):
#     """
#     يرجع السعر بعد الخصم حسب مستوى المستخدم
#     مع 4 أرقام عشرية بعد الفاصلة
#     """
#     if package.is_custom:
#         base_price = package.product.coins_price or Decimal("0.0")
#     else:
#         base_price = package.price or Decimal("0.0")

#     # تأكد من وجود userprofile
#     try:
#         userprofile = user.userprofile
#         level = getattr(userprofile, "level", None)
#     except AttributeError:
#         level = None

#     discount_rate = settings.DISCOUNT_CHOICES.get(level, Decimal("0.0"))
#     discounted = base_price * (1 - discount_rate)

#     # تحويل الرقم ليظهر بأربع أرقام عشرية
#     return discounted.quantize(Decimal("0.0001"), rounding=ROUND_DOWN)


from django import template
from django.conf import settings
from decimal import Decimal, ROUND_DOWN
from products.models import ExchangeRate

register = template.Library()

@register.filter
def increased_price(package, user):
    """
    يرجع السعر بعد إضافة نسبة الربح حسب مستوى المستخدم
    مع 4 أرقام عشرية بعد الفاصلة
    """
    if package.is_custom:
        base_price = package.product.coins_price or Decimal("0.0")
    else:
        base_price = package.price or Decimal("0.0")

    try:
        userprofile = user.userprofile
        level = getattr(userprofile, "level", None)
    except AttributeError:
        level = None

    profit_rate = settings.PROFIT_CHOICES.get(level, Decimal("0.0"))
    increased = base_price * (1 + profit_rate)

    return increased.quantize(Decimal("0.000001"), rounding=ROUND_DOWN)


@register.filter
def format_price(price, user):
    """
    تنسيق السعر حسب عملة المستخدم
    """
    try:
        userprofile = user.userprofile
        currency = getattr(userprofile, "currency", "USD")
    except AttributeError:
        currency = "USD"
    
    if currency == "SYP":
        exchange_rate = ExchangeRate.get_current_rate()
        converted_price = Decimal(str(price)) * exchange_rate
        return f"{converted_price:.2f} SYP"
    else:
        return f"${Decimal(str(price)):.4f}"


@register.filter
def currency_symbol(user):
    """
    إرجاع رمز العملة للمستخدم
    """
    try:
        userprofile = user.userprofile
        currency = getattr(userprofile, "currency", "USD")
    except AttributeError:
        currency = "USD"
    
    return "SYP" if currency == "SYP" else "$"


@register.filter
def convert_price(price, user):
    """
    تحويل السعر حسب عملة المستخدم (بدون رمز)
    """
    try:
        userprofile = user.userprofile
        currency = getattr(userprofile, "currency", "USD")
    except AttributeError:
        currency = "USD"
    
    if currency == "SYP":
        exchange_rate = ExchangeRate.get_current_rate()
        converted_price = Decimal(str(price)) * exchange_rate
        return converted_price.quantize(Decimal("0.01"), rounding=ROUND_DOWN)
    else:
        return Decimal(str(price)).quantize(Decimal("0.0001"), rounding=ROUND_DOWN)
