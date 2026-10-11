from .models import UserNotification

def unread_notifications(request):
    """يتم تمرير عدد الإشعارات غير المقروءة إلى القوالب"""
    unread_count = 0
    if request.user.is_authenticated:
        # الحصول على عدد الإشعارات غير المقروءة للمستخدم
        unread_count = UserNotification.objects.filter(user=request.user, read=False).count()
    
    return {
        'unread_notifications_count': unread_count,
    }
