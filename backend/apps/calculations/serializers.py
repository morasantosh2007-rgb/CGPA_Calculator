from rest_framework import serializers
from .models import SemesterResult, AcademicSummary

class SemesterResultSerializer(serializers.ModelSerializer):
    semester_number = serializers.IntegerField(source='semester.semester_number', read_only=True)

    class Meta:
        model = SemesterResult
        fields = (
            'id', 'semester', 'semester_number', 'sgpa',
            'total_credits_registered', 'total_credits_earned',
            'has_backlogs', 'calculated_at'
        )

class AcademicSummarySerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.full_name', read_only=True)
    registration_number = serializers.CharField(source='student.registration_number', read_only=True)
    university_name = serializers.CharField(source='student.university.name', read_only=True, default='')

    class Meta:
        model = AcademicSummary
        fields = (
            'id', 'student', 'student_name', 'registration_number', 'university_name',
            'cgpa', 'total_credits_completed', 'total_backlogs_count',
            'cleared_backlogs_count', 'active_backlogs_count',
            'highest_sgpa', 'lowest_sgpa', 'updated_at'
        )
