from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from services.analytics.service import AnalyticsService

class ProgressionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        data = AnalyticsService.get_progression(request.user.student_profile)
        return Response(data)

class GradeDistributionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        data = AnalyticsService.get_grade_distribution(request.user.student_profile)
        return Response(data)

class WhatIfSimulatorView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        payload = request.data
        hypothetical_grades = payload.get('hypothetical_grades', [])
        result = AnalyticsService.simulate_what_if(request.user.student_profile, hypothetical_grades)
        return Response(result, status=status.HTTP_200_OK)

class TargetCGPACalculatorView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        payload = request.data
        target_cgpa = float(payload.get('target_cgpa', 0.0))
        remaining_credits = float(payload.get('remaining_credits', 0.0))
        result = AnalyticsService.calculate_target_requirement(
            request.user.student_profile, target_cgpa, remaining_credits
        )
        return Response(result, status=status.HTTP_200_OK)
