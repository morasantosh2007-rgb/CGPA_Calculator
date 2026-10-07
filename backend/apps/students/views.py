import uuid
from django.contrib.auth import get_user_model
from rest_framework import generics, viewsets, status
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import University, StudentProfile
from .serializers import UniversitySerializer, StudentProfileSerializer
from .utils import get_active_student_profile, ensure_default_grading_system

class UniversityViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]
    queryset = University.objects.all()
    serializer_class = UniversitySerializer

class StudentProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [AllowAny]
    serializer_class = StudentProfileSerializer

    def get_object(self):
        return get_active_student_profile(self.request)

class StudentSetupView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        data = request.data
        full_name = (data.get('full_name') or '').strip()
        reg_no = (data.get('registration_number') or '').strip()
        roll_no = (data.get('roll_number') or reg_no).strip()
        department = (data.get('department') or '').strip()
        academic_year = (data.get('academic_year') or '').strip()
        institute_email = (data.get('institute_email') or '').strip().lower()
        uni_name = (data.get('university_name') or '').strip()

        default_system, default_policy = ensure_default_grading_system()

        profile = None
        if reg_no:
            profile = StudentProfile.objects.filter(registration_number__iexact=reg_no).first()
        if not profile and institute_email:
            profile = StudentProfile.objects.filter(institute_email__iexact=institute_email).first()

        if profile:
            if full_name:
                profile.full_name = full_name
            if roll_no:
                profile.roll_number = roll_no
            if department:
                profile.department = department
            if academic_year:
                profile.academic_year = academic_year
            if uni_name:
                profile.university_name = uni_name
            if institute_email:
                profile.institute_email = institute_email
            profile.save()
        else:
            User = get_user_model()
            user_email = institute_email or f"{reg_no or uuid.uuid4().hex[:8]}@gradelens.local"
            user = User.objects.filter(email=user_email).first()
            if not user:
                user = User.objects.create(
                    email=user_email,
                    username=user_email,
                    full_name=full_name or 'Student'
                )
                user.set_unusable_password()
                user.save()

            profile = StudentProfile.objects.create(
                user=user,
                full_name=full_name or 'Student',
                registration_number=reg_no,
                roll_number=roll_no,
                department=department,
                academic_year=academic_year,
                institute_email=institute_email,
                university_name=uni_name,
                grading_system=default_system,
                calculation_policy=default_policy
            )

        return Response(StudentProfileSerializer(profile).data, status=status.HTTP_200_OK)
