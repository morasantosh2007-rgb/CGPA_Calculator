from rest_framework import generics, viewsets
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import University, StudentProfile
from .serializers import UniversitySerializer, StudentProfileSerializer
from .utils import get_active_student_profile

class UniversityViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]
    queryset = University.objects.all()
    serializer_class = UniversitySerializer

class StudentProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [AllowAny]
    serializer_class = StudentProfileSerializer

    def get_object(self):
        return get_active_student_profile(self.request)
