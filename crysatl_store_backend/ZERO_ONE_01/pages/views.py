from django.shortcuts import render
from django.http import HttpResponse
from products.models import Product, Agent, Category

# Create your views here.
def index(request):
    # جلب جميع المنتجات والفئات
    products = Product.objects.filter(is_active=True)
    categories = Category.objects.all().order_by('ordering')
    # تمرير المنتجات والفئات في الـ context
    context = {
        'products': products,
        'categories': categories,
    }

    return render(request, 'pages/index.html', context)


def terms(request):

    # تمرير العدد إلى القالب
    return render(request, 'pages/terms.html')


def about(request):
    # جلب الوكلاء النشطين
    agents = Agent.objects.filter(is_active=True)

    # تمرير الوكلاء وعدد الإشعارات غير المقروءة في الـ context
    return render(request, 'pages/about.html', {
        'agents': agents,
        
    })


def api_docs(request):
    """عرض صفحة وثائق API"""
    return render(request, 'api_docs.html')