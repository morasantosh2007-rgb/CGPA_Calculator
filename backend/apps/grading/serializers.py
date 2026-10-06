from rest_framework import serializers
from .models import GradingSystem, GradeRule, CalculationPolicy

class GradeRuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = GradeRule
        fields = ('id', 'grade', 'grade_point', 'is_pass', 'counts_for_sgpa', 'counts_for_cgpa')

class GradingSystemSerializer(serializers.ModelSerializer):
    rules = GradeRuleSerializer(many=True, read_only=True)

    class Meta:
        model = GradingSystem
        fields = ('id', 'name', 'code', 'description', 'is_default', 'rules')

class CalculationPolicySerializer(serializers.ModelSerializer):
    class Meta:
        model = CalculationPolicy
        fields = ('id', 'code', 'name', 'description', 'is_default')
