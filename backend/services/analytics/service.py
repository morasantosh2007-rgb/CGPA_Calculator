from decimal import Decimal
from apps.subjects.models import EffectiveSubjectResult

class AnalyticsService:
    """Computes academic progression trends, grade distribution, and simulation models."""

    @classmethod
    def get_progression(cls, student_profile):
        semesters = student_profile.semesters.all().order_by('semester_number').select_related('result')
        progression = []

        cumulative_points = Decimal('0.00')
        cumulative_credits = Decimal('0.00')

        for sem in semesters:
            sgpa = float(sem.result.sgpa) if hasattr(sem, 'result') and sem.result else 0.0
            sem_credits = float(sem.result.total_credits_registered) if hasattr(sem, 'result') and sem.result else 0.0

            # Compute cumulative up to this semester
            eff_results = sem.effective_results.all()
            for r in eff_results:
                c = Decimal(str(r.effective_credits))
                gp = Decimal(str(r.effective_grade_point))
                if c > 0:
                    cumulative_points += c * gp
                    cumulative_credits += c

            rolling_cgpa = float(round(cumulative_points / cumulative_credits, 2)) if cumulative_credits > 0 else 0.0

            progression.append({
                'semester_number': sem.semester_number,
                'sgpa': sgpa,
                'rolling_cgpa': rolling_cgpa,
                'credits': sem_credits,
                'status': sem.status
            })

        return {
            'progression': progression,
            'highest_sgpa': max([p['sgpa'] for p in progression], default=0.0),
            'lowest_sgpa': min([p['sgpa'] for p in progression], default=0.0) if progression else 0.0,
            'total_semesters': len(progression)
        }

    @classmethod
    def get_grade_distribution(cls, student_profile):
        results = EffectiveSubjectResult.objects.filter(semester__student=student_profile)
        distribution = {
            'EX': 0, 'A': 0, 'B': 0, 'C': 0,
            'D': 0, 'P': 0, 'M': 0, 'F': 0, 'OTHER': 0
        }
        for r in results:
            g = r.effective_grade.upper()
            if g in distribution:
                distribution[g] += 1
            else:
                distribution['OTHER'] += 1
        return distribution

    @classmethod
    def simulate_what_if(cls, student_profile, hypothetical_grades):
        """
        Calculates projected CGPA if backlogs or subjects are improved.
        hypothetical_grades: list of {'subject_id': uuid, 'grade': 'B'}
        """
        eff_results = list(EffectiveSubjectResult.objects.filter(semester__student=student_profile))
        rules_map = {r.grade: r.grade_point for r in student_profile.grading_system.rules.all()} if student_profile.grading_system else {}

        # Default rules map fallback
        default_scale = {'EX': 10.0, 'A': 9.0, 'B': 8.0, 'C': 7.0, 'D': 6.0, 'P': 5.0, 'M': 4.0, 'F': 0.0}
        for k, v in default_scale.items():
            if k not in rules_map:
                rules_map[k] = Decimal(str(v))

        # Current calculation
        curr_points = Decimal('0.00')
        curr_credits = Decimal('0.00')
        for r in eff_results:
            c = Decimal(str(r.effective_credits))
            gp = Decimal(str(r.effective_grade_point))
            if c > 0:
                curr_points += c * gp
                curr_credits += c

        current_cgpa = float(round(curr_points / curr_credits, 2)) if curr_credits > 0 else 0.0

        # Projected calculation
        override_map = {str(item.get('subject_id')): item.get('grade', '').upper() for item in hypothetical_grades}
        proj_points = Decimal('0.00')

        for r in eff_results:
            c = Decimal(str(r.effective_credits))
            sub_id_str = str(r.subject_id)
            if sub_id_str in override_map:
                new_grade = override_map[sub_id_str]
                gp = Decimal(str(rules_map.get(new_grade, 0.0)))
            else:
                gp = Decimal(str(r.effective_grade_point))

            if c > 0:
                proj_points += c * gp

        projected_cgpa = float(round(proj_points / curr_credits, 2)) if curr_credits > 0 else 0.0
        delta = round(projected_cgpa - current_cgpa, 2)

        return {
            'current_cgpa': current_cgpa,
            'projected_cgpa': projected_cgpa,
            'delta': delta,
            'total_credits': float(curr_credits),
            'label': 'PROJECTED / WHAT-IF'
        }

    @classmethod
    def calculate_target_requirement(cls, student_profile, target_cgpa, remaining_credits):
        summary = getattr(student_profile, 'academic_summary', None)
        current_cgpa = float(summary.cgpa) if summary else 0.0
        completed_credits = float(summary.total_credits_completed) if summary else 0.0

        if remaining_credits <= 0:
            return {
                'is_achievable': current_cgpa >= target_cgpa,
                'required_average_grade_point': 0.0,
                'message': 'No remaining credits provided.'
            }

        total_credits = completed_credits + remaining_credits
        current_points = current_cgpa * completed_credits
        required_points = (target_cgpa * total_credits) - current_points
        required_gpa = required_points / remaining_credits

        is_achievable = 0.0 <= required_gpa <= 10.0

        if required_gpa > 10.0:
            message = "Target is not achievable under the current grading configuration (requires > 10.0 GP)."
        elif required_gpa < 4.0:
            message = "Target is easily achievable; passing all remaining courses will exceed target."
        else:
            message = f"You need an average grade point of {required_gpa:.2f} across the remaining {remaining_credits:.1f} credits."

        return {
            'target_cgpa': target_cgpa,
            'current_cgpa': current_cgpa,
            'completed_credits': completed_credits,
            'remaining_credits': remaining_credits,
            'required_average_grade_point': round(required_gpa, 2),
            'is_achievable': is_achievable,
            'message': message
        }
