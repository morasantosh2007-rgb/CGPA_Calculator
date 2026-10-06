from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import AcademicSummary, SemesterResult
from .serializers import AcademicSummarySerializer, SemesterResultSerializer
from services.calculation.engine import CalculationEngine
from apps.students.utils import get_active_student_profile

class AcademicSummaryView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        profile = get_active_student_profile(request)
        summary = CalculationEngine.calculate_academic_summary(profile)
        return Response(AcademicSummarySerializer(summary).data)

class RecalculateAllView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        profile = get_active_student_profile(request)
        for sem in profile.semesters.all():
            CalculationEngine.reconcile_semester(sem)
        summary = CalculationEngine.calculate_academic_summary(profile)
        return Response({
            'message': 'All semesters and cumulative standing successfully recalculated.',
            'summary': AcademicSummarySerializer(summary).data
        }, status=status.HTTP_200_OK)
