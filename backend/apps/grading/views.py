from rest_framework import generics
from rest_framework.permissions import AllowAny
from .models import GradingSystem, CalculationPolicy
from .serializers import GradingSystemSerializer, CalculationPolicySerializer

class GradingSystemListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    queryset = GradingSystem.objects.all().prefetch_related('rules')
    serializer_class = GradingSystemSerializer

class CalculationPolicyListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    queryset = CalculationPolicy.objects.all()
    serializer_class = CalculationPolicySerializer
