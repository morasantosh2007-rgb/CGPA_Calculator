from rest_framework import serializers
from .models import University, StudentProfile
from apps.grading.serializers import GradingSystemSerializer, CalculationPolicySerializer

class UniversitySerializer(serializers.ModelSerializer):
    class Meta:
        model = University
        fields = ('id', 'name', 'code', 'country')

class StudentProfileSerializer(serializers.ModelSerializer):
    university_detail = UniversitySerializer(source='university', read_only=True)
    grading_system_detail = GradingSystemSerializer(source='grading_system', read_only=True)
    calculation_policy_detail = CalculationPolicySerializer(source='calculation_policy', read_only=True)

    class Meta:
        model = StudentProfile
        fields = (
            'id', 'full_name', 'registration_number', 'roll_number',
            'department', 'academic_year', 'institute_email', 'university_name',
            'university', 'university_detail',
            'grading_system', 'grading_system_detail',
            'calculation_policy', 'calculation_policy_detail',
            'created_at', 'updated_at'
        )
