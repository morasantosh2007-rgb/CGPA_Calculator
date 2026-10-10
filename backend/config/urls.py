from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from django.http import JsonResponse
from django.views.static import serve
from django.urls import re_path

def health_check(request):
    return JsonResponse({
        'status': 'healthy',
        'service': 'GradeNexus Backend API',
        'version': '1.0.0'
    })

urlpatterns = [
    path('', health_check, name='root_health'),
    path('health/', health_check, name='health_check'),
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.users.urls')),
    path('api/students/', include('apps.students.urls')),
    path('api/grading/', include('apps.grading.urls')),
    path('api/semesters/', include('apps.semesters.urls')),
    path('api/grade-sheets/', include('apps.gradesheets.urls')),
    path('api/subjects/', include('apps.subjects.urls')),
    path('api/calculations/', include('apps.calculations.urls')),
    path('api/processing/', include('apps.processing.urls')),
    path('api/analytics/', include('apps.analytics.urls')),
    path('api/reports/', include('apps.reports.urls')),
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    re_path(r'^static/(?P<path>.*)$', serve, {'document_root': settings.STATIC_ROOT}),
]

