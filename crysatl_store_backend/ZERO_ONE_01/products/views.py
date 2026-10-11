from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required

from accounts.models import UserNotification
from .models import Category, Product, Package


@login_required(login_url='signin')
def categories_and_products(request):
    from .models import ExchangeRate
    
    # عرض الفئات الأساسية فقط (بدون فئات فرعية)
    parent_categories = Category.objects.filter(parent_category__isnull=True).order_by('ordering')
    products = Product.objects.all()
    subcategories = None
    selected_parent_category = None

    selected_category = request.GET.get('category')
    unread_notifications_count = UserNotification.objects.filter(user=request.user, read=False).count()

    if selected_category:
        selected_category_obj = Category.objects.filter(id=selected_category).first()
        if selected_category_obj:
            # إذا كانت الفئة المختارة هي فئة أساسية ولديها فئات فرعية
            if selected_category_obj.parent_category is None and selected_category_obj.subcategories.exists():
                # عرض الفئات الفرعية فقط (بدون منتجات)
                subcategories = selected_category_obj.subcategories.all()
                selected_parent_category = selected_category_obj
                products = Product.objects.none()  # لا توجد منتجات في هذه الحالة
            # إذا كانت الفئة المختارة هي فئة فرعية
            elif selected_category_obj.parent_category is not None:
                # عرض منتجات الفئة الفرعية
                products = products.filter(category__id=selected_category)
            # إذا كانت الفئة الأساسية بدون فئات فرعية
            else:
                # عرض منتجات الفئة الأساسية مباشرة
                products = products.filter(category__id=selected_category)
        
        
    products = products.order_by('-is_active')
    
    # Get exchange rate for JavaScript
    exchange_rate = ExchangeRate.get_current_rate()

    context = {
        'categories': parent_categories,  # الفئات الأساسية فقط
        'products': products,
        'subcategories': subcategories,  # الفئات الفرعية (إذا تم اختيار فئة أساسية)
        'selected_category_id': selected_category,
        'selected_parent_category': selected_parent_category,
        'unread_notifications_count': unread_notifications_count,
        'exchange_rate': exchange_rate,
    }
    
    return render(request, 'products/products.html', context)


@login_required(login_url='signin')
def products_and_packages(request, id):
    from .models import ExchangeRate
    
    product = get_object_or_404(Product, id=id)
    packages = product.packages.all()  # الحصول على الباقات المرتبطة بالمنتج
    unread_notifications_count = UserNotification.objects.filter(user=request.user, read=False).count()
    
    # Get exchange rate for JavaScript
    exchange_rate = ExchangeRate.get_current_rate()

    context = {
        'product': product,
        'packages': packages,
        'unread_notifications_count': unread_notifications_count,
        'exchange_rate': exchange_rate,
    }
    return render(request, 'products/packages.html', context)




@login_required(login_url='signin')
def packages(request):
    pack = Package.objects.all()
    search_term = None
    unread_notifications_count = UserNotification.objects.filter(user=request.user, read=False).count()


    if 'searchterm' in request.GET:
        search_term = request.GET['searchterm']
        if search_term:
            pack = pack.filter(name__icontains=search_term)  # تصفية الباقات


    context = {
        'packages': pack,
        'searchterm': search_term,
        'unread_notifications_count': unread_notifications_count,  # إضافة العدد هنا

    }
    
    return render(request, 'products/packages.html', context)


@login_required(login_url='signin')
def package(request, id):
    from .models import ExchangeRate
    
    # الحصول على الباقة باستخدام المعرف
    package = get_object_or_404(Package, id=id)
    unread_notifications_count = UserNotification.objects.filter(user=request.user, read=False).count()
    
    # Get exchange rate for JavaScript
    exchange_rate = ExchangeRate.get_current_rate()

    # إعداد السياق
    context = {
        'package': package,
        'unread_notifications_count': unread_notifications_count,
        'exchange_rate': exchange_rate,
    }
    
    # عرض القالب مع بيانات الباقة
    return render(request, 'products/package_detaile.html', context)
