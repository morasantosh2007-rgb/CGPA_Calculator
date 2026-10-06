import io
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

class PDFReportGenerator:
    """Generates official academic audit reports in PDF format."""

    @classmethod
    def generate_transcript_pdf(cls, student_profile):
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )

        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            'DocTitle',
            parent=styles['Heading1'],
            fontSize=18,
            textColor=colors.HexColor('#1E293B'),
            spaceAfter=6,
            alignment=1
        )
        subtitle_style = ParagraphStyle(
            'DocSub',
            parent=styles['Normal'],
            fontSize=10,
            textColor=colors.HexColor('#64748B'),
            spaceAfter=15,
            alignment=1
        )
        h2_style = ParagraphStyle(
            'SectionH2',
            parent=styles['Heading2'],
            fontSize=12,
            textColor=colors.HexColor('#0F172A'),
            spaceBefore=10,
            spaceAfter=6
        )
        normal_style = styles['Normal']

        elements = []

        # Title
        elements.append(Paragraph("GradeLens — Official Academic Audit Transcript", title_style))
        inst_name = student_profile.university.name if student_profile.university else "Academic Institution"
        elements.append(Paragraph(f"Institution: {inst_name} | Generated via GradeLens Document Intelligence", subtitle_style))

        # Student Info Card Table
        summary = getattr(student_profile, 'academic_summary', None)
        cgpa_str = f"{summary.cgpa:.2f}" if summary else "N/A"
        credits_str = f"{summary.total_credits_completed:.1f}" if summary else "0.0"
        backlogs_str = f"{summary.active_backlogs_count}" if summary else "0"

        info_data = [
            [Paragraph(f"<b>Student Name:</b> {student_profile.full_name or 'N/A'}", normal_style),
             Paragraph(f"<b>Current CGPA:</b> <font color='#2563EB'><b>{cgpa_str}</b></font>", normal_style)],
            [Paragraph(f"<b>Registration No:</b> {student_profile.registration_number or 'N/A'}", normal_style),
             Paragraph(f"<b>Total Credits Earned:</b> {credits_str}", normal_style)],
            [Paragraph(f"<b>Roll No:</b> {student_profile.roll_number or 'N/A'}", normal_style),
             Paragraph(f"<b>Active Backlogs:</b> {backlogs_str}", normal_style)]
        ]
        info_table = Table(info_data, colWidths=[270, 270])
        info_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
            ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#E2E8F0')),
            ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ]))
        elements.append(info_table)
        elements.append(Spacer(1, 15))

        # Semesters Breakdown
        semesters = student_profile.semesters.all().order_by('semester_number')
        for sem in semesters:
            sem_sgpa = f"{sem.result.sgpa:.2f}" if hasattr(sem, 'result') and sem.result else "N/A"
            elements.append(Paragraph(f"Semester {sem.semester_number} — Final SGPA: <b>{sem_sgpa}</b>", h2_style))

            table_data = [["Code", "Subject Title", "Credits", "Raw Grade", "Effective Grade", "GP", "Status"]]
            eff_results = sem.effective_results.all()
            for r in eff_results:
                status_str = "PASS" if r.is_pass else "FAIL"
                table_data.append([
                    r.subject.subject_code or "-",
                    r.subject.subject_name[:30],
                    str(r.effective_credits),
                    r.selected_attempt.raw_grade,
                    r.effective_grade,
                    str(r.effective_grade_point),
                    status_str
                ])

            t = Table(table_data, colWidths=[65, 200, 50, 65, 75, 40, 45])
            t.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0F172A')),
                ('TEXTCOLOR', (0,0), (-1,0), colors.white),
                ('ALIGN', (2,0), (-1,-1), 'CENTER'),
                ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
                ('FONTSIZE', (0,0), (-1,-1), 8),
                ('BOTTOMPADDING', (0,0), (-1,-1), 4),
                ('TOPPADDING', (0,0), (-1,-1), 4),
                ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
                ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')]),
            ]))
            elements.append(t)
            elements.append(Spacer(1, 10))

        doc.build(elements)
        buffer.seek(0)
        return buffer.getvalue()

    @classmethod
    def generate_audit_json(cls, student_profile):
        summary = getattr(student_profile, 'academic_summary', None)
        data = {
            'student': {
                'name': student_profile.full_name,
                'registration_number': student_profile.registration_number,
                'cgpa': float(summary.cgpa) if summary else 0.0,
                'total_credits': float(summary.total_credits_completed) if summary else 0.0,
            },
            'semesters': []
        }

        for sem in student_profile.semesters.all().order_by('semester_number'):
            sem_data = {
                'semester_number': sem.semester_number,
                'sgpa': float(sem.result.sgpa) if hasattr(sem, 'result') and sem.result else 0.0,
                'attempts': [],
                'effective_results': []
            }
            for att in sem.attempts.all().order_by('attempt_number'):
                sem_data['attempts'].append({
                    'attempt_number': att.attempt_number,
                    'exam_type': att.exam_type,
                    'subjects': [
                        {
                            'code': sa.subject.subject_code,
                            'name': sa.subject.subject_name,
                            'grade': sa.normalized_grade,
                            'credits': float(sa.credits),
                            'grade_point': float(sa.grade_point),
                            'user_corrected': sa.user_corrected
                        }
                        for sa in att.subject_attempts.all()
                    ]
                })

            for eff in sem.effective_results.all():
                sem_data['effective_results'].append({
                    'code': eff.subject.subject_code,
                    'name': eff.subject.subject_name,
                    'effective_grade': eff.effective_grade,
                    'effective_grade_point': float(eff.effective_grade_point),
                    'effective_credits': float(eff.effective_credits),
                    'is_pass': eff.is_pass
                })

            data['semesters'].append(sem_data)

        return data
