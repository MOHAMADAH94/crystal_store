from django.contrib import admin
from django.utils.html import format_html
from .models import (
    APIKey,
    ExternalStore
)

# =========================
# API KEY
# =========================
@admin.register(APIKey)
class APIKeyAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'key', 'is_active', 'created_at', 'last_used')
    list_filter = ('is_active', 'created_at')
    search_fields = ('name', 'key', 'user__username')
    readonly_fields = ('key', 'created_at', 'last_used')

    def get_readonly_fields(self, request, obj=None):
        if obj:
            return self.readonly_fields + ('key',)
        return self.readonly_fields


# =========================
# EXTERNAL STORE
# =========================
@admin.register(ExternalStore)
class ExternalStoreAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'base_url', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at', 'user')
    search_fields = ('name', 'base_url', 'user__username')
    autocomplete_fields = ('user',)

