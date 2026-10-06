from django.urls import path
from .views import ProgressionView, GradeDistributionView, WhatIfSimulatorView, TargetCGPACalculatorView

urlpatterns = [
    path('progression/', ProgressionView.as_view(), name='analytics_progression'),
    path('distribution/', GradeDistributionView.as_view(), name='analytics_distribution'),
    path('what-if/', WhatIfSimulatorView.as_view(), name='analytics_what_if'),
    path('target/', TargetCGPACalculatorView.as_view(), name='analytics_target'),
]
