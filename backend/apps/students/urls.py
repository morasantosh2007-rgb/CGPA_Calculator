from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import UniversityViewSet, StudentProfileView

router = DefaultRouter()
router.register('universities', UniversityViewSet, basename='universities')

urlpatterns = [
    path('profile/', StudentProfileView.as_view(), name='student_profile'),
    path('', include(router.urls)),
]
