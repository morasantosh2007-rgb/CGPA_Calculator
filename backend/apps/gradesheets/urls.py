from django.urls import path
from .views import GradeSheetUploadView, GradeSheetListView, GradeSheetDetailView, GradeSheetVerifyView

urlpatterns = [
    path('', GradeSheetListView.as_view(), name='gradesheet_list'),
    path('upload/', GradeSheetUploadView.as_view(), name='gradesheet_upload'),
    path('<uuid:pk>/', GradeSheetDetailView.as_view(), name='gradesheet_detail'),
    path('<uuid:pk>/verify/', GradeSheetVerifyView.as_view(), name='gradesheet_verify'),
]
