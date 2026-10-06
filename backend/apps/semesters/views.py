from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Semester, AcademicAttempt
from .serializers import SemesterSerializer, AcademicAttemptSerializer
from apps.students.utils import get_active_student_profile

class SemesterViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.AllowAny]
    serializer_class = SemesterSerializer

    def get_queryset(self):
        profile = get_active_student_profile(self.request)
        return Semester.objects.filter(
            student=profile
        ).prefetch_related('attempts', 'effective_results', 'attempts__subject_attempts').select_related('result')

    def perform_create(self, serializer):
        profile = get_active_student_profile(self.request)
        serializer.save(student=profile)

    @action(detail=True, methods=['get'])
    def attempts(self, request, pk=None):
        semester = self.get_object()
        attempts = semester.attempts.all().prefetch_related('subject_attempts')
        serializer = AcademicAttemptSerializer(attempts, many=True)
        return Response(serializer.data)

class AcademicAttemptViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.AllowAny]
    serializer_class = AcademicAttemptSerializer

    def get_queryset(self):
        profile = get_active_student_profile(self.request)
        return AcademicAttempt.objects.filter(
            semester__student=profile
        ).prefetch_related('subject_attempts')
