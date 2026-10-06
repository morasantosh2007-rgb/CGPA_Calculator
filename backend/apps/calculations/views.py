from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import AcademicSummary, SemesterResult
from .serializers import AcademicSummarySerializer, SemesterResultSerializer
from services.calculation.engine import CalculationEngine

class AcademicSummaryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile = request.user.student_profile
        summary = CalculationEngine.calculate_academic_summary(profile)
        return Response(AcademicSummarySerializer(summary).data)

class RecalculateAllView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        profile = request.user.student_profile
        for sem in profile.semesters.all():
            CalculationEngine.reconcile_semester(sem)
        summary = CalculationEngine.calculate_academic_summary(profile)
        return Response({
            'message': 'All semesters and cumulative standing successfully recalculated.',
            'summary': AcademicSummarySerializer(summary).data
        }, status=status.HTTP_200_OK)
