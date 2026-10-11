@echo off
echo تشغيل سيرفر Django للوصول من المحاكي...
cd /d %~dp0
python manage.py runserver 0.0.0.0:8000
pause
