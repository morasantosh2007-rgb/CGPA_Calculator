from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Semester, AcademicAttempt
from .serializers import SemesterSerializer, AcademicAttemptSerializer

class SemesterViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = SemesterSerializer

    def get_queryset(self):
        return Semester.objects.filter(
            student__user=self.request.user
        ).prefetch_related('attempts', 'effective_results', 'attempts__subject_attempts').select_related('result')

    def perform_create(self, serializer):
        profile = self.request.user.student_profile
        serializer.save(student=profile)

    @action(detail=True, methods=['get'])
    def attempts(self, request, pk=None):
        semester = self.get_object()
        attempts = semester.attempts.all().prefetch_related('subject_attempts')
        serializer = AcademicAttemptSerializer(attempts, many=True)
        return Response(serializer.data)

class AcademicAttemptViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = AcademicAttemptSerializer

    def get_queryset(self):
        return AcademicAttempt.objects.filter(
            semester__student__user=self.request.user
        ).prefetch_related('subject_attempts')
