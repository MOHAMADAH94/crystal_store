from django.http import JsonResponse
from django.shortcuts import render,redirect
from django.shortcuts import get_object_or_404
from django.contrib import messages,auth
from django.contrib.auth.models import User,auth
from django.contrib.auth.decorators import login_required
from django.db.models import F, ExpressionWrapper, DecimalField, Sum


# from accounts.forms import NotificationForm
from .models import BalanceLog, Notification, UserProfile,UserNotification,PaymentMethod
from products.models import Package
from django.core.paginator import Paginator
from django.db.models import F
import re
from django.core.files.storage import FileSystemStorage
from .models import Balance_add  # تأكد من أنك تستورد النموذج الصحيح
import random
import os


# Create your views here.


from django.contrib.auth.models import User

def signin(request):
    if request.method == 'POST':
        username = request.POST['username']
        password = request.POST['password']

        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            user = None

        if user is not None:
            if not user.is_active:
                messages.warning(request, 'حسابك غير مفعل، يرجى تفعيل الحساب أولاً.')
                return redirect('signin')
            else:
                user = auth.authenticate(username=username, password=password)
                if user is not None:
                    auth.login(request, user)
                    if 'remember' in request.POST:
                        request.session.set_expiry(1209600)
                    else:
                        request.session.set_expiry(0)
                    
                    # التحقق من وجود PIN
                    try:
                        user_profile = UserProfile.objects.get(user=user)
                        if user_profile.pin and user_profile.pin.strip():
                            # إذا كان لديه PIN، احفظ في session وأرسله لصفحة التحقق
                            request.session['needs_pin_verification'] = True
                            return redirect('verify_pin')
                    except UserProfile.DoesNotExist:
                        pass
                    
                    return redirect('products')
                else:
                    messages.warning(request, 'كلمة المرور غير صحيحة.')
                    return redirect('signin')
        else:
            messages.warning(request, 'اسم المستخدم غير موجود.')
            return redirect('signin')

    return render(request, 'accounts/signin.html')





def signup(request):
    if request.method == 'POST' and 'btnsignup' in request.POST:
        fname=None
        lname=None
        address=None
        address2=None
        phone=None
        state=None
        city=None
        email=None
        password=None
        username=None
        terms=None
        is_added=None
    

        # Get values from the form
        fname = request.POST.get('fname')
        lname = request.POST.get('lname')
        address = request.POST.get('address')
        address2 = request.POST.get('address2')
        city = request.POST.get('city')
        state = request.POST.get('state')
        phone = request.POST.get('phone')
        email = request.POST.get('email')
        username = request.POST.get('username')
        password = request.POST.get('password')
        terms = request.POST.get('terms')

        # Validate the form data
        if all([fname, lname, address, address2, city, state, phone, email, username, password]):
            if terms == 'on':
                if User.objects.filter(username=username).exists():
                    messages.error(request, 'اسم المستخدم محجوز مسبقا')
                elif User.objects.filter(email=email).exists():
                    messages.error(request, 'الايميل تم استخدامه مسبقا')
                else:
                    patt = r'^(\w|\.|\_|\-)+[@](\w|\_|\-|\.)+[.]\w{2,3}$'
                    if re.match(patt, email):
                        # Create user
                        user = User.objects.create_user(
                            first_name=fname,
                            last_name=lname,
                            email=email,
                            username=username,
                            password=password
                        )
                        user.is_active = True
                        user.save()
                        # Get currency from form (default to USD if not provided)
                        currency = request.POST.get('currency', 'USD')
                        if currency not in ['USD', 'SYP']:
                            currency = 'USD'
                        
                        # Create user profile with default balance
                        userprofile=UserProfile(
                            user=user,
                            address=address,
                            address2=address2,
                            city=city,
                            state=state,
                            phone=phone,
                            balance=0.00,  # Set default balance
                            currency=currency
                            
                        )
                        userprofile.save()

                        #clear filed
                        fname=''
                        lname=''
                        address=''
                        address2=''
                        phone=''
                        state=''
                        city=''
                        email=''
                        password=''
                        username=''
                        terms=None



                        messages.success(request, 'تم انشاء الحساب بنجاح ')

                        is_added=True
                    else:
                        messages.warning(request, 'Email is invalid.')
            else:
                messages.warning(request, 'You must agree to the terms.')
        else:
            messages.warning(request, 'Please check empty fields.')

        currency = request.POST.get('currency', 'USD')
        return render(request, 'accounts/signup.html', {
            'fname': fname,
            'lname': lname,
            'address': address,
            'address2': address2,
            'city': city,
            'state': state,
            'phone': phone,
            'email': email,
            'username': username,
            'terms': terms,
            'is_added':is_added,
            'currency': currency,
        })
    else:
        return render(request, 'accounts/signup.html')




def profile(request):
    if not request.user.is_authenticated:
        return redirect('signin')

    userprofile, created = UserProfile.objects.get_or_create(
        user=request.user,
        defaults={
            'address': '---',
            'address2': '---',
            'city': '---',
            'state': '---',
            'phone': '0000000000',
            'balance': 0.0,
            'level': 'vip1',  # استخدام level المناسب كنص
        }
    )

    if request.method == 'POST' and 'btnsave' in request.POST:
        required_fields = ['fname', 'lname', 'address', 'city', 'state', 'phone', 'email', 'username', 'password', 'balance', 'level']
        if all(request.POST.get(field, '').strip() != '' for field in required_fields):
            request.user.first_name = request.POST['fname']
            request.user.last_name = request.POST['lname']
            userprofile.address = request.POST['address']
            userprofile.address2 = request.POST.get('address2', '')
            userprofile.city = request.POST['city']
            userprofile.state = request.POST['state']
            userprofile.phone = request.POST['phone']
            userprofile.balance = float(request.POST['balance'])
            userprofile.level = request.POST['level']

            new_password = request.POST['password']
            if not new_password.startswith('pbkdf2_sha256$'):
                request.user.set_password(new_password)
                auth.login(request, request.user)  # إعادة تسجيل الدخول

            request.user.save()
            userprofile.save()

            messages.success(request, 'تم تحديث معلومات الحساب.')
            return redirect('profile')
        else:
            messages.error(request, 'الرجاء التحقق من الحقول.')

    context = {
        'userprofile': userprofile,
        'fname': request.user.first_name,
        'lname': request.user.last_name,
        'address': userprofile.address,
        'address2': userprofile.address2,
        'city': userprofile.city,
        'state': userprofile.state,
        'phone': userprofile.phone,
        'email': request.user.email,
        'username': request.user.username,
        'balance': userprofile.balance,
        'level': userprofile.level,
        'password': request.user.password,
    }
    return render(request, 'accounts/profile.html', context)


def signout(request):
    if request.user.is_authenticated:
        auth.logout(request)
    return redirect('index')






def favorite_package(request, pack_id):
    fav_pack = get_object_or_404(Package, pk=pack_id)

    if request.user.is_authenticated:
        userprofile, created = UserProfile.objects.get_or_create(user=request.user)
        
        if userprofile.favorite_package.filter(id=pack_id).exists():
            userprofile.favorite_package.remove(fav_pack)
            messages.success(request, 'تمت الإزالة من المفضلة')
        else:
            userprofile.favorite_package.add(fav_pack)
            messages.success(request, 'تمت الاضافة للمفضلة')
    else:
        messages.warning(request, 'عليك تسجيل الدخول أولا')

    # return redirect('products/package_detaile.html', pack_id=pack_id)
    return render(request, 'products/package_detaile.html', {'package': fav_pack})





def show_favorite_package(request):
    context = {}
    if request.user.is_authenticated and not request.user.is_anonymous:
        # التأكد من وجود UserProfile أو إنشاؤه إذا لم يكن موجودًا
        userInfo, created = UserProfile.objects.get_or_create(
            user=request.user,
            defaults={
                'address': '---',
                'address2': '---',
                'city': '---',
                'state': '---',
                'phone': '0000000000',
                'balance': 0.0,
                'level': 'vip1',  # المستوى الافتراضي
            }
        )

        # الحصول على الباقات المفضلة
        pack = userInfo.favorite_package.all()  # أو favorite_packages حسب اسم العلاقة
        context = {'packages': pack}

    return render(request, 'products/packages.html', context)





def balance_history(request):
    if not request.user.is_authenticated:
        return render(request, 'login.html')

    # كل السجلات للمستخدم
    all_logs = BalanceLog.objects.filter(user_profile__user=request.user).annotate(
        difference=ExpressionWrapper(F('new_balance') - F('old_balance'), output_field=DecimalField())
    ).order_by('-change_date')

    # فلترة حسب الطلب
    filter_type = request.GET.get('filter')
    if filter_type == 'deposits':
        balance_logs = all_logs.filter(difference__gt=0)
    elif filter_type == 'withdrawals':
        balance_logs = all_logs.filter(difference__lt=0)
    else:
        balance_logs = all_logs

    # مجموع السحوبات والدفعات
    total_deposits = all_logs.filter(difference__gt=0).aggregate(total=Sum('difference'))['total'] or 0
    total_withdrawals = all_logs.filter(difference__lt=0).aggregate(total=Sum('difference'))['total'] or 0

    # التصفح
    paginator = Paginator(balance_logs, 10)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    profile = getattr(request.user, 'userprofile', None)
    current_balance = profile.balance if profile else 0

    return render(request, 'accounts/balance_history.html', {
        'balance_logs': page_obj,
        'total_deposits': total_deposits,
        'total_withdrawals': total_withdrawals,
        'current_balance': current_balance,
    })




from django.conf import settings
from django.core.files.storage import FileSystemStorage

from django.conf import settings
from django.core.files.storage import FileSystemStorage

def send_money(request):
    payments_list = Balance_add.objects.filter(user=request.user).order_by('-created_at')
    
    # إعداد التصفح
    paginator = Paginator(payments_list, 10)  # عرض 10 دفعات في الصفحة
    page_number = request.GET.get('page')  # الحصول على رقم الصفحة من الاستعلام
    payments = paginator.get_page(page_number)  # الحصول على دفعات الصفحة الحالية

    # إضافة طرق الدفع المتاحة
    payment_methods = PaymentMethod.objects.all()

    if request.method == 'POST' and request.user.is_authenticated:
        try:
            amount = float(request.POST['amount'])
            send_amount = float(request.POST['send_amount'])
            payment_method_id = int(request.POST['payment_method'])

            # تحقق من وجود طريقة الدفع
            payment_method = PaymentMethod.objects.get(id=payment_method_id)

            # تحويل الخصم إلى float إذا كان من نوع Decimal
            discount_percentage = float(payment_method.discount_percentage)
            
            # حساب المبلغ بعد تطبيق نسبة الخصم
            discounted_amount = amount * (1 - discount_percentage / 100)  # تطبيق الخصم على المبلغ

            if 'receipt' not in request.FILES:
                messages.error(request, "يرجى تحميل إيصال.")
                return render(request, 'accounts/send_money.html', {'payments': payments, 'payment_methods': payment_methods})

            receipt = request.FILES['receipt']

            # استخراج الامتداد من اسم الملف الأصلي
            original_extension = os.path.splitext(receipt.name)[1]  # الحصول على الامتداد مثل .jpg أو .png
            
            # توليد رقم عشوائي
            random_number = random.randint(100000, 999999)
            
            # استبدال اسم الصورة برقم عشوائي مع الحفاظ على الامتداد
            receipt_name = str(random_number) + original_extension

            # استخدام FileSystemStorage مع المسار الصحيح
            fs = FileSystemStorage(location=settings.MEDIA_ROOT + '/receipts_images/')
            receipt_path = fs.save(receipt_name, receipt)  # حفظ الإيصال

            Balance_add.objects.create(
                user=request.user,
                amount=discounted_amount,  # استخدام المبلغ بعد الخصم
                receipt=f'receipts_images/{receipt_name}',  # حفظ الاسم المعدل
                is_processed=False,
                payment_method=payment_method  # حفظ طريقة الدفع مع الطلب
            )

            messages.success(request, "تم إرسال طلب الدفعة بنجاح. سيتم مراجعته من قبل الأدمن.")
            return redirect('send_money')

        except ValueError:
            messages.error(request, "يرجى إدخال قيم صحيحة للأموال.")
            return render(request, 'accounts/send_money.html', {'payments': payments, 'payment_methods': payment_methods})

        except PaymentMethod.DoesNotExist:
            messages.error(request, "طريقة الدفع المختارة غير صحيحة.")
            return render(request, 'accounts/send_money.html', {'payments': payments, 'payment_methods': payment_methods})

        except Exception as e:
            messages.error(request, f"حدث خطأ: {str(e)}")
            return render(request, 'accounts/send_money.html', {'payments': payments, 'payment_methods': payment_methods})

    return render(request, 'accounts/send_money.html', {'payments': payments, 'payment_methods': payment_methods})



@login_required(login_url='signin')
def send_notification(request):
    # عدد الإشعارات غير المقروءة للمستخدم
    unread_notifications_count = UserNotification.objects.filter(user=request.user, read=False).count()

    # استرجاع جميع الإشعارات للمستخدم مع حالة القراءة
    notifications_with_status = (
        UserNotification.objects.filter(user=request.user)
        .select_related('notification')  # استخدام select_related لتحميل الإشعار والمستخدم في استعلام واحد
        .order_by('-notification__created_at')  # ترتيب الإشعارات حسب تاريخ الإنشاء
    )

    # التخصيص لصفحات الإشعارات
    paginator = Paginator(notifications_with_status, 10)  # 10 إشعارات في كل صفحة
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    # تحويل البيانات لتسهيل استخدامها في القالب
    notifications_data = [{
        'notification': user_notification.notification,
        'is_read': user_notification.read,
    } for user_notification in page_obj]

    # عرض الصفحة مع الإشعارات
    return render(request, 'accounts/notifications.html', {
        'notifications_data': notifications_data,
        'unread_notifications_count': unread_notifications_count,
        'page_obj': page_obj,  # تمرير الـ pagination
    })



@login_required
def mark_as_read(request, notification_id):
    # استرجاع الإشعار
    notification = Notification.objects.get(id=notification_id)

    # الحصول على الكائن UserNotification أو إنشاؤه إذا لم يكن موجودًا
    user_notification, created = UserNotification.objects.get_or_create(
        user=request.user,
        notification=notification
    )

    # إذا كان الإشعار غير مقروء، قم بتحديثه إلى مقروء
    if not user_notification.read:
        user_notification.read = True
        user_notification.save()

    # إرجاع استجابة JSON لتحديث حالة الإشعار في الصفحة
    return JsonResponse({
        'success': True,
        'notification_id': notification.id,
        'unread_count': get_unread_notifications_count(request.user),
    })

def get_unread_notifications_count(user):
    return UserNotification.objects.filter(user=user, read=False).count()


@login_required(login_url='signin')
def verify_pin(request):
    """صفحة التحقق من PIN"""
    # التحقق من أن المستخدم مسجل دخول
    if not request.user.is_authenticated:
        return redirect('signin')
    
    # التحقق من وجود PIN في ملف المستخدم
    try:
        user_profile = UserProfile.objects.get(user=request.user)
        has_pin = bool(user_profile.pin and user_profile.pin.strip())
        
        # إذا لم يكن لديه PIN، اذهب مباشرة للمنتجات
        if not has_pin:
            if 'needs_pin_verification' in request.session:
                del request.session['needs_pin_verification']
            return redirect('products')
    except UserProfile.DoesNotExist:
        return redirect('products')
    
    if request.method == 'POST':
        pin = request.POST.get('pin', '').strip()
        
        if not pin:
            messages.error(request, 'يرجى إدخال رمز PIN')
            return render(request, 'accounts/verify_pin.html')
        
        # التحقق من PIN
        if user_profile.pin == pin:
            # PIN صحيح، احذف flag من session
            if 'needs_pin_verification' in request.session:
                del request.session['needs_pin_verification']
            messages.success(request, 'تم التحقق من PIN بنجاح')
            return redirect('products')
        else:
            messages.error(request, 'رمز PIN غير صحيح')
            return render(request, 'accounts/verify_pin.html')
    
    return render(request, 'accounts/verify_pin.html')


# def google_redirect(request):
#     if request.user.is_authenticated:
#         if not request.user.is_active:
#             messages.error(request, 'حسابك غير مفعل، يرجى التواصل مع الدعم الفني.')
#             return redirect('logout')  # أو أي صفحة أخرى
#         return redirect('home')  # إذا كان مفعل، تابع بشكل طبيعي
#     return redirect('login')