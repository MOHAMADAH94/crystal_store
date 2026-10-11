from rest_framework import authentication, exceptions
from django.utils import timezone
from .models import APIKey


class APIKeyAuthentication(authentication.BaseAuthentication):
    """مصادقة باستخدام API Key"""
    
    def authenticate(self, request):
        api_key = request.META.get('HTTP_X_API_KEY') or request.GET.get('api_key')
        
        if not api_key:
            return None
        
        try:
            api_key_obj = APIKey.objects.get(key=api_key, is_active=True)
            api_key_obj.last_used = timezone.now()
            api_key_obj.save(update_fields=['last_used'])
            return (api_key_obj.user, None)
        except APIKey.DoesNotExist:
            raise exceptions.AuthenticationFailed('Invalid API Key')
    
    def authenticate_header(self, request):
        return 'API-Key'

