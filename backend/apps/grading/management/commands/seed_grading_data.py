from django.core.management.base import BaseCommand
from decimal import Decimal
from apps.grading.models import GradingSystem, GradeRule, CalculationPolicy

class Command(BaseCommand):
    help = 'Seeds default GradeLens grading rules (EX=10..F=0) and calculation policies'

    def handle(self, *args, **kwargs):
        self.stdout.write("Seeding GradeLens Grading Systems & Calculation Policies...")

        # 1. Default Grading System
        system, _ = GradingSystem.objects.get_or_create(
            code='DEFAULT_EX_F',
            defaults={
                'name': 'GradeLens Standard 10-Point Scale (EX-F)',
                'description': 'Exact institutional scale: EX=10, A=9, B=8, C=7, D=6, P=5, M=4, F=0',
                'is_default': True
            }
        )

        rules_data = [
            ('EX', Decimal('10.00'), True, 1),
            ('A',  Decimal('9.00'),  True, 2),
            ('B',  Decimal('8.00'),  True, 3),
            ('C',  Decimal('7.00'),  True, 4),
            ('D',  Decimal('6.00'),  True, 5),
            ('P',  Decimal('5.00'),  True, 6),
            ('M',  Decimal('4.00'),  True, 7),
            ('F',  Decimal('0.00'),  False, 8),
        ]

        for grade, gp, is_pass, order in rules_data:
            GradeRule.objects.update_or_create(
                grading_system=system,
                grade=grade,
                defaults={
                    'grade_point': gp,
                    'is_pass': is_pass,
                    'counts_for_sgpa': True,
                    'counts_for_cgpa': True,
                    'order': order
                }
            )

        # 2. Calculation Policies
        policies = [
            (
                'POLICY_A_LATEST_PASS',
                'Policy A: Latest Passing Grade (Default)',
                'Latest passing attempt replaces failed attempt in SGPA & CGPA with zero double-counting.',
                True
            ),
            (
                'POLICY_B_FROZEN_SGPA',
                'Policy B: Frozen Historical SGPA',
                'Historical semester SGPA remains unchanged, but cumulative CGPA uses improved grade.',
                False
            ),
            (
                'POLICY_C_HIGHEST_GRADE',
                'Policy C: Highest Grade Achieved',
                'The highest grade achieved among all attempts is preserved.',
                False
            ),
            (
                'POLICY_D_INSTITUTIONAL',
                'Policy D: Custom Institutional Policy',
                'Institution-specific backlog recalculation rules.',
                False
            ),
        ]

        for code, name, desc, is_def in policies:
            CalculationPolicy.objects.update_or_create(
                code=code,
                defaults={
                    'name': name,
                    'description': desc,
                    'is_default': is_def
                }
            )

        self.stdout.write(self.style.SUCCESS("Successfully seeded GradeLens grading and policy configurations."))
