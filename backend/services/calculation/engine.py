from decimal import Decimal, ROUND_HALF_UP
from apps.semesters.models import Semester
from apps.subjects.models import Subject, SubjectAttempt, EffectiveSubjectResult
from apps.calculations.models import SemesterResult, AcademicSummary

class CalculationEngine:
    """Enterprise Pure Mathematical SGPA and CGPA Calculation Engine."""

    @staticmethod
    def round_two_decimals(val):
        return Decimal(str(val)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    @classmethod
    def calculate_sgpa(cls, effective_results):
        """
        Computes SGPA = Σ(Credit × GradePoint) / Σ(Credits)
        Failed subjects (F, 0 GP) contribute 0 to numerator, but their credits
        remain fully in the denominator.
        """
        total_points = Decimal('0.00')
        total_credits = Decimal('0.00')
        earned_credits = Decimal('0.00')
        has_backlogs = False

        for res in effective_results:
            credits = Decimal(str(res.effective_credits))
            gp = Decimal(str(res.effective_grade_point))
            
            if credits > 0:
                total_points += credits * gp
                total_credits += credits
                if res.is_pass:
                    earned_credits += credits
                else:
                    has_backlogs = True

        if total_credits == 0:
            sgpa = Decimal('0.00')
        else:
            sgpa = cls.round_two_decimals(total_points / total_credits)

        return sgpa, total_credits, earned_credits, has_backlogs

    @classmethod
    def reconcile_semester(cls, semester, policy_code='POLICY_A_LATEST_PASS'):
        """
        Reconciles all attempts for a semester, resolving effective subject results
        and recalculating the semester SGPA.
        """
        # Fetch all attempts for this semester ordered by attempt number
        attempts = semester.attempts.all().order_by('attempt_number')
        all_subject_attempts = SubjectAttempt.objects.filter(
            academic_attempt__in=attempts
        ).select_related('subject', 'academic_attempt')

        # Group attempts by canonical subject
        grouped_by_subject = {}
        for sa in all_subject_attempts:
            sub_id = sa.subject_id
            if sub_id not in grouped_by_subject:
                grouped_by_subject[sub_id] = []
            grouped_by_subject[sub_id].append(sa)

        # Resolve effective result for each subject according to policy
        effective_list = []
        for sub_id, sub_attempts in grouped_by_subject.items():
            # Sort by attempt number
            sub_attempts.sort(key=lambda x: x.academic_attempt.attempt_number)
            
            if policy_code == 'POLICY_C_HIGHEST_GRADE':
                chosen = max(sub_attempts, key=lambda x: x.grade_point)
            elif policy_code in ('POLICY_A_LATEST_PASS', 'POLICY_B_FROZEN_SGPA'):
                # Take latest passing attempt; if student hasn't passed, take latest attempt
                passing = [a for a in sub_attempts if a.is_pass]
                chosen = passing[-1] if passing else sub_attempts[-1]
            else:
                chosen = sub_attempts[-1]

            # Upsert EffectiveSubjectResult
            eff_res, _ = EffectiveSubjectResult.objects.update_or_create(
                semester=semester,
                subject=chosen.subject,
                defaults={
                    'selected_attempt': chosen,
                    'effective_grade': chosen.normalized_grade,
                    'effective_grade_point': chosen.grade_point,
                    'effective_credits': chosen.credits,
                    'is_pass': chosen.is_pass
                }
            )
            effective_list.append(eff_res)

        # Calculate SGPA
        sgpa, tot_cred, earn_cred, has_backlogs = cls.calculate_sgpa(effective_list)

        # Save SemesterResult
        res, _ = SemesterResult.objects.update_or_create(
            semester=semester,
            defaults={
                'sgpa': sgpa,
                'total_credits_registered': tot_cred,
                'total_credits_earned': earn_cred,
                'has_backlogs': has_backlogs
            }
        )

        # Update Semester status
        semester.status = 'BACKLOGS_PENDING' if has_backlogs else 'COMPLETED'
        semester.save()

        return res

    @classmethod
    def calculate_academic_summary(cls, student_profile):
        """
        Computes cumulative CGPA across all effective subjects:
        CGPA = Σ(Credit × GradePoint across all effective results) / Σ(Credits)
        Never averages semester SGPAs!
        """
        semesters = student_profile.semesters.all().prefetch_related('effective_results', 'result')
        
        total_points = Decimal('0.00')
        total_effective_credits = Decimal('0.00')
        total_earned_credits = Decimal('0.00')
        active_backlogs = 0
        all_sgpas = []

        for sem in semesters:
            eff_results = sem.effective_results.all()
            for r in eff_results:
                c = Decimal(str(r.effective_credits))
                gp = Decimal(str(r.effective_grade_point))
                if c > 0:
                    total_points += c * gp
                    total_effective_credits += c
                    if r.is_pass:
                        total_earned_credits += c
                    else:
                        active_backlogs += 1

            if hasattr(sem, 'result') and sem.result:
                all_sgpas.append(sem.result.sgpa)

        cgpa = cls.round_two_decimals(total_points / total_effective_credits) if total_effective_credits > 0 else Decimal('0.00')
        highest_sgpa = max(all_sgpas) if all_sgpas else Decimal('0.00')
        lowest_sgpa = min(all_sgpas) if all_sgpas else Decimal('0.00')

        summary, _ = AcademicSummary.objects.update_or_create(
            student=student_profile,
            defaults={
                'cgpa': cgpa,
                'total_credits_completed': total_earned_credits,
                'active_backlogs_count': active_backlogs,
                'highest_sgpa': highest_sgpa,
                'lowest_sgpa': lowest_sgpa
            }
        )
        return summary
