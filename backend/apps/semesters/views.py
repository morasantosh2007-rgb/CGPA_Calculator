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

    def perform_destroy(self, instance):
        from apps.gradesheets.models import GradeSheet
        from services.calculation.engine import CalculationEngine

        profile = instance.student
        sem_num = instance.semester_number

        # Decouple any gradesheet attempts
        for attempt in instance.attempts.all():
            GradeSheet.objects.filter(academic_attempt=attempt).update(academic_attempt=None)

        # Remove gradesheets explicitly associated with this semester for this student
        GradeSheet.objects.filter(student=profile, detected_semester=sem_num).delete()

        # Delete the semester (cascades to attempts, subject attempts, effective results, semester result)
        instance.delete()

        # Recalculate academic summary & CGPA across remaining semesters
        CalculationEngine.calculate_academic_summary(profile)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        sem_num = instance.semester_number
        profile = instance.student
        self.perform_destroy(instance)

        from apps.calculations.models import AcademicSummary
        summary = AcademicSummary.objects.filter(student=profile).first()
        cgpa_val = float(summary.cgpa) if summary else 0.0

        return Response({
            'message': f'Semester {sem_num} deleted successfully and CGPA recalculated.',
            'semester_deleted': sem_num,
            'cgpa': cgpa_val
        })

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
