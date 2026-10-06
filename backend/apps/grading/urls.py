from django.urls import path
from .views import GradingSystemListView, CalculationPolicyListView

urlpatterns = [
    path('systems/', GradingSystemListView.as_view(), name='grading_systems'),
    path('policies/', CalculationPolicyListView.as_view(), name='calculation_policies'),
]
