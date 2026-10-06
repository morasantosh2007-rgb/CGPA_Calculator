from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import SubjectViewSet, SubjectAttemptUpdateView

router = DefaultRouter()
router.register('', SubjectViewSet, basename='subjects')

urlpatterns = [
    path('attempts/<uuid:pk>/', SubjectAttemptUpdateView.as_view(), name='subject_attempt_update'),
    path('', include(router.urls)),
]
