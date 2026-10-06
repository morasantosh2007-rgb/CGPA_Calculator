from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
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
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
