from rest_framework import generics, viewsets
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from .models import University, StudentProfile
from .serializers import UniversitySerializer, StudentProfileSerializer
from apps.grading.models import GradingSystem, CalculationPolicy

class UniversityViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]
    queryset = University.objects.all()
    serializer_class = UniversitySerializer

class StudentProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = StudentProfileSerializer

    def get_object(self):
        default_system = GradingSystem.objects.filter(is_default=True).first()
        default_policy = CalculationPolicy.objects.filter(is_default=True).first()
        profile, _ = StudentProfile.objects.get_or_create(
            user=self.request.user,
            defaults={
                'full_name': self.request.user.full_name or '',
                'grading_system': default_system,
                'calculation_policy': default_policy,
            }
        )
        return profile
