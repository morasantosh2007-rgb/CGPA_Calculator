from decimal import Decimal
from django.contrib.auth import get_user_model
from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, GradeRule, CalculationPolicy

def ensure_default_grading_system():
    """Seeds standard 10-point academic grading scale if not present."""
    system, created = GradingSystem.objects.get_or_create(
        code='STANDARD_10_POINT',
        defaults={
            'name': 'Standard 10-Point Academic Grading System',
            'description': 'EX/A/B/C/D/P/F 10-point scale adopted by NITs and IITs',
            'is_default': True,
        }
    )
    if not system.is_default:
        system.is_default = True
        system.save(update_fields=['is_default'])

    if created or not system.rules.exists():
        rules_data = [
            ('EX', Decimal('10.00'), True, 1),
            ('A', Decimal('9.00'), True, 2),
            ('B', Decimal('8.00'), True, 3),
            ('C', Decimal('7.00'), True, 4),
            ('D', Decimal('6.00'), True, 5),
            ('P', Decimal('5.00'), True, 6),
            ('M', Decimal('4.00'), True, 7),
            ('F', Decimal('0.00'), False, 8),
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
                    'order': order,
                }
            )

    policy, _ = CalculationPolicy.objects.get_or_create(
        code='POLICY_A_LATEST_PASS',
        defaults={
            'name': 'Policy A: Latest Passing Grade Replacement',
            'description': 'Latest passing attempt replaces backlogs for SGPA and CGPA integrity.',
            'is_default': True,
        }
    )
    return system, policy

def get_active_student_profile(request=None):
    """
    Seamless profile resolver supporting multi-device isolation:
    1. Checks 'X-Student-Id' request header.
    2. Checks 'X-Registration-Number' request header.
    3. Checks request.user if authenticated.
    4. Fallback to default student profile.
    Guarantees that `student_profile` always exists and never throws RelatedObjectDoesNotExist.
    """
    default_system, default_policy = ensure_default_grading_system()

    if request:
        # 1. Check X-Student-Id header
        student_id = request.headers.get('X-Student-Id') if hasattr(request, 'headers') else None
        if not student_id and hasattr(request, 'META'):
            student_id = request.META.get('HTTP_X_STUDENT_ID')
        if student_id:
            try:
                p = StudentProfile.objects.filter(id=student_id).first()
                if p:
                    return p
            except Exception:
                pass

        # 2. Check X-Registration-Number header
        reg_no = request.headers.get('X-Registration-Number') if hasattr(request, 'headers') else None
        if not reg_no and hasattr(request, 'META'):
            reg_no = request.META.get('HTTP_X_REGISTRATION_NUMBER')
        if reg_no:
            p = StudentProfile.objects.filter(registration_number__iexact=reg_no.strip()).first()
            if p:
                return p

        # 3. Check authenticated user
        if hasattr(request, 'user') and request.user and request.user.is_authenticated:
            profile, _ = StudentProfile.objects.get_or_create(
                user=request.user,
                defaults={
                    'full_name': request.user.full_name or 'Santosh Mora',
                    'registration_number': 'REG2024001',
                    'grading_system': default_system,
                    'calculation_policy': default_policy,
                }
            )
            return profile

    # 4. Fallback: retrieve MORA SANTOSH or first existing profile
    profile = StudentProfile.objects.filter(registration_number='424154').first()
    if not profile:
        profile = StudentProfile.objects.first()

    if not profile:
        User = get_user_model()
        user = User.objects.filter(email='student@gradelens.local').first()
        if not user:
            user = User.objects.create(
                email='student@gradelens.local',
                username='student@gradelens.local',
                full_name='MORA SANTOSH'
            )
            user.set_unusable_password()
            user.save()

        profile = StudentProfile.objects.create(
            user=user,
            full_name='MORA SANTOSH',
            registration_number='424154',
            roll_number='424154',
            department='Computer Science & Engineering',
            academic_year='3rd Year (B.Tech)',
            institute_email='424154@student.nitandhra.ac.in',
            university_name='National Institute of Technology Andhra Pradesh',
            grading_system=default_system,
            calculation_policy=default_policy,
        )

    # Ensure defaults are linked to profile
    if not profile.grading_system:
        profile.grading_system = default_system
        profile.save(update_fields=['grading_system'])

    if not profile.calculation_policy:
        profile.calculation_policy = default_policy
        profile.save(update_fields=['calculation_policy'])

    return profile
