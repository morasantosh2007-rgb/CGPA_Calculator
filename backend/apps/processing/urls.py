from django.urls import path
from .views import ProcessingJobDetailView, ProcessingJobListView

urlpatterns = [
    path('', ProcessingJobListView.as_view(), name='processing_job_list'),
    path('<uuid:pk>/', ProcessingJobDetailView.as_view(), name='processing_job_detail'),
]
