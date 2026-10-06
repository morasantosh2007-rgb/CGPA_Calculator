from django.urls import path
from .views import AcademicSummaryView, RecalculateAllView

urlpatterns = [
    path('summary/', AcademicSummaryView.as_view(), name='academic_summary'),
    path('recalculate/', RecalculateAllView.as_view(), name='recalculate_all'),
]
