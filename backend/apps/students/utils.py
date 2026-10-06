from django.contrib.auth import get_user_model
from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, CalculationPolicy

def get_active_student_profile(request=None):
    """
    Seamless profile resolver:
    1. If user is authenticated, retrieves or auto-initializes their StudentProfile.
    2. If unauthenticated / direct access mode, retrieves or auto-creates the default student profile.
    Guarantees that `student_profile` always exists and never throws RelatedObjectDoesNotExist.
    """
    default_system = GradingSystem.objects.filter(is_default=True).first()
    default_policy = CalculationPolicy.objects.filter(is_default=True).first()

    if request and hasattr(request, 'user') and request.user and request.user.is_authenticated:
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

    User = get_user_model()
    user = User.objects.filter(email='student@gradelens.local').first()
    if not user:
        user = User.objects.create(
            email='student@gradelens.local',
            username='student@gradelens.local',
            full_name='Santosh Mora'
        )
        user.set_unusable_password()
        user.save()

    profile, _ = StudentProfile.objects.get_or_create(
        user=user,
        defaults={
            'full_name': 'Santosh Mora',
            'registration_number': 'REG2024001',
            'grading_system': default_system,
            'calculation_policy': default_policy,
        }
    )

    # Ensure defaults are linked
    if not profile.grading_system and default_system:
        profile.grading_system = default_system
        profile.save(update_fields=['grading_system'])

    if not profile.calculation_policy and default_policy:
        profile.calculation_policy = default_policy
        profile.save(update_fields=['calculation_policy'])

    return profile
