from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import SemesterViewSet, AcademicAttemptViewSet

router = DefaultRouter()
router.register('', SemesterViewSet, basename='semesters')
router.register('attempts', AcademicAttemptViewSet, basename='attempts')

urlpatterns = [
    path('', include(router.urls)),
]
