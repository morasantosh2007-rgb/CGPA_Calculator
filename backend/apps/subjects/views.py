from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Subject, SubjectAttempt, EffectiveSubjectResult
from .serializers import SubjectSerializer, SubjectAttemptSerializer, EffectiveSubjectResultSerializer
from services.calculation.engine import CalculationEngine
from apps.students.utils import get_active_student_profile

class SubjectViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.AllowAny]
    serializer_class = SubjectSerializer

    def get_queryset(self):
        profile = get_active_student_profile(self.request)
        return Subject.objects.filter(
            student=profile
        ).prefetch_related('attempts', 'attempts__academic_attempt')

class SubjectAttemptUpdateView(APIView):
    permission_classes = [permissions.AllowAny]

    def patch(self, request, pk):
        profile = get_active_student_profile(request)
        try:
            attempt = SubjectAttempt.objects.get(
                pk=pk,
                subject__student=profile
            )
        except SubjectAttempt.DoesNotExist:
            return Response({'error': 'Subject attempt not found'}, status=status.HTTP_404_NOT_FOUND)

        data = request.data
        if 'grade' in data:
            old_val = attempt.normalized_grade
            attempt.original_value = old_val
            attempt.raw_grade = data['grade']
            attempt.normalized_grade = data['grade'].strip().upper()
            attempt.user_corrected = True
            
            # Map grade point from grading system
            rule = profile.grading_system.rules.filter(grade=attempt.normalized_grade).first() if profile.grading_system else None
            if rule:
                attempt.grade_point = rule.grade_point
                attempt.is_pass = rule.is_pass
            else:
                return Response({'error': f"Unknown grade '{data['grade']}'"}, status=status.HTTP_400_BAD_REQUEST)

        if 'credits' in data:
            attempt.credits = data['credits']
            attempt.user_corrected = True

        attempt.save()

        # Recalculate semester and cumulative standing
        semester = attempt.academic_attempt.semester
        CalculationEngine.reconcile_semester(semester)
        CalculationEngine.calculate_academic_summary(profile)

        return Response(SubjectAttemptSerializer(attempt).data)
