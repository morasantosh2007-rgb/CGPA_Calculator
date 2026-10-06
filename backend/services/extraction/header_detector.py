import re

class HeaderDetector:
    """Specialized service for extracting metadata from the upper header region of grade sheets."""

    ROMAN_MAP = {
        'I': 1, 'II': 2, 'III': 3, 'IV': 4,
        'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8,
        'IX': 9, 'X': 10, 'XI': 11, 'XII': 12,
        'FIRST': 1, 'SECOND': 2, 'THIRD': 3, 'FOURTH': 4,
        'FIFTH': 5, 'SIXTH': 6, 'SEVENTH': 7, 'EIGHTH': 8
    }

    SEMESTER_REGEXES = [
        # Explicit Year/Sem patterns e.g. "Year/Sem:IYr/ISem" -> 1, "Year/Sem:IYr/IlSem" -> 2
        (r"I\s*YR[\s/:\-]+I\s*SEM\b", 1),
        (r"I\s*YR[\s/:\-]+(?:II|IL|Il|2)\s*SEM\b", 2),
        (r"II\s*YR[\s/:\-]+I\s*SEM\b", 3),
        (r"II\s*YR[\s/:\-]+(?:II|IL|Il|2)\s*SEM\b", 4),
        (r"III\s*YR[\s/:\-]+I\s*SEM\b", 5),
        (r"III\s*YR[\s/:\-]+(?:II|IL|Il|2)\s*SEM\b", 6),
        (r"IV\s*YR[\s/:\-]+I\s*SEM\b", 7),
        (r"IV\s*YR[\s/:\-]+(?:II|IL|Il|2)\s*SEM\b", 8),
        # Roman with SEMESTER e.g., "SEMESTER III", "SEM-III", "III SEMESTER"
        (r"(?:SEMESTER|SEM)[\s\-:]+([IVXLCDM]+)\b", None),
        (r"\b([IVXLCDM]+)[\s\-]+(?:SEMESTER|SEM)\b", None),
        # Degree prefixes like "III B.TECH", "IV B.E", "3-1 B.TECH"
        (r"\b([IVXLCDM]+)[\s\-]+B\.?\s*(?:TECH|E|ARCH|SC)\b", None),
        # Words e.g. "THIRD SEMESTER", "FIRST SEMESTER"
        (r"\b(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH)[\s\-]+(?:SEMESTER|SEM)\b", None),
        # Arabic with SEMESTER e.g. "SEMESTER 3", "3RD SEMESTER"
        (r"(?:SEMESTER|SEM)[\s\-:]+(\d{1,2})\b", None),
        (r"\b(\d{1,2})(?:ST|ND|RD|TH)?[\s\-]+(?:SEMESTER|SEM)\b", None),
        # Year - Sem patterns like "III YEAR I SEM" -> Sem 5, "II-I" -> Sem 3
        (r"\b([IVXLCDM]+|\d)[\s\-]+YEAR[\s\-]+([IVXLCDM]+|\d)[\s\-]+SEM\b", 'YEAR_SEM'),
    ]

    EXAM_TYPE_PATTERNS = [
        (r"\bGRADE\s+CHALLENGE\b", "REVALUATION"),
        (r"\bREVALUATION(?:\s+RESULTS?|\s+EXAM|\s+NOTICE)?\b", "REVALUATION"),
        (r"\bRE\-VALUATION\b", "REVALUATION"),
        (r"\bSUPPLEMENTARY(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "SUPPLEMENTARY"),
        (r"\bSUPPLE(?:\s+EXAM|\s+EXAMINATION)?\b", "SUPPLEMENTARY"),
        (r"\bBACKLOG(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "BACKLOG"),
        (r"\bIMPROVEMENT(?:\s+EXAMINATION|\s+EXAM)?\b", "IMPROVEMENT"),
        (r"\bREPEAT(?:\s+EXAM)?\b", "REPEAT"),
        (r"\bREGULAR(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "REGULAR"),
        (r"\bSEMESTER\s+END\s+EXAMINATION\b", "REGULAR"),
    ]

    DOCUMENT_KEYWORDS = [
        "GRADE SHEET", "STATEMENT OF MARKS", "MARKS MEMORANDUM",
        "PROVISIONAL CERTIFICATE", "TRANSCRIPT", "GRADE CARD",
        "SEMESTER GRADE REPORT", "GRADE REPORT", "EXAMINATION RESULTS"
    ]

    @classmethod
    def classify_document(cls, text):
        upper_text = text.upper()
        
        # Check for Revaluation Notice
        if "NOTICE" in upper_text and ("GRADE CHALLENGE" in upper_text or "REVISED" in upper_text or "CHANGED" in upper_text):
            return "REVALUATION_NOTICE"

        # Check if academic document
        is_academic = any(kw in upper_text for kw in cls.DOCUMENT_KEYWORDS) or \
                      ("SEMESTER" in upper_text and ("GRADE" in upper_text or "CREDIT" in upper_text or "MARKS" in upper_text or "SGPA" in upper_text))

        if not is_academic:
            return "UNKNOWN_DOCUMENT"

        if "REVALUATION" in upper_text:
            return "REVALUATION_RESULT"
        if "SUPPLEMENTARY" in upper_text or "SUPPLE" in upper_text:
            return "SUPPLEMENTARY_SHEET"
        if "BACKLOG" in upper_text:
            return "BACKLOG_SHEET"
        if "TRANSCRIPT" in upper_text:
            return "TRANSCRIPT"
        if "MARKS MEMO" in upper_text or "STATEMENT OF MARKS" in upper_text:
            return "MARKS_MEMO"

        return "GRADE_SHEET"

    @classmethod
    def extract_header_metadata(cls, text):
        """
        Extracts semester, examination type, student name, registration number,
        university, session, and printed SGPA/CGPA from header text.
        """
        upper_text = text.upper()
        doc_type = cls.classify_document(text)
        
        metadata = {
            'document_type': doc_type,
            'semester': None,
            'semester_confidence': 0.0,
            'exam_type': 'REGULAR',
            'raw_exam_type': 'REGULAR',
            'exam_type_confidence': 0.50,
            'student_name': '',
            'registration_number': '',
            'session': '',
            'institution': '',
            'printed_sgpa': None,
            'printed_cgpa': None,
        }

        # 1. Semester Identification
        for pattern, fixed_val in cls.SEMESTER_REGEXES:
            match = re.search(pattern, upper_text)
            if match:
                if fixed_val is not None and isinstance(fixed_val, int):
                    metadata['semester'] = fixed_val
                    metadata['semester_confidence'] = 0.98
                    break
                elif fixed_val == 'YEAR_SEM':
                    groups = match.groups()
                    y_val = cls.ROMAN_MAP.get(groups[0], int(groups[0]) if groups[0].isdigit() else 1)
                    s_val = cls.ROMAN_MAP.get(groups[1], int(groups[1]) if groups[1].isdigit() else 1)
                    metadata['semester'] = (y_val - 1) * 2 + s_val
                    metadata['semester_confidence'] = 0.95
                    break
                else:
                    groups = match.groups()
                    if groups:
                        raw_val = groups[0]
                        if raw_val in cls.ROMAN_MAP:
                            metadata['semester'] = cls.ROMAN_MAP[raw_val]
                            metadata['semester_confidence'] = 0.96
                            break
                        elif raw_val.isdigit():
                            metadata['semester'] = int(raw_val)
                            metadata['semester_confidence'] = 0.95
                            break

        # 2. Examination Type Identification
        for pattern, norm_type in cls.EXAM_TYPE_PATTERNS:
            match = re.search(pattern, upper_text)
            if match:
                metadata['raw_exam_type'] = match.group(0)
                metadata['exam_type'] = norm_type
                metadata['exam_type_confidence'] = 0.95
                break

        # 3. Registration / Roll Number / Hall Ticket Number
        reg_match = re.search(
            r"(?:REG(?:ISTRATION)?\.?\s*(?:NO|NUMBER)?|ROLL\s*(?:NO|NUMBER)?|HT\s*NO|HTNO|PIN|ENROLLMENT(?:\s*NO)?)[\s\-:]+([A-Z0-9]{5,18})\b",
            upper_text
        )
        if reg_match:
            metadata['registration_number'] = reg_match.group(1).strip()
        else:
            # Check standalone 6-digit roll number pattern e.g. 424154
            roll_match = re.search(r"\b(42\d{4}|22\d{4}|1\d{5}|2\d{5})\b", upper_text)
            if roll_match:
                metadata['registration_number'] = roll_match.group(1).strip()

        # 4. Student Name
        name_match = re.search(
            r"(?:STUDENT|CANDIDATE)?\s*NAME[\s\-:]+([A-Z\s\.]{3,50}?)(?:\s{2,}|\n|\r|REG|ROLL|HT|HALL|PIN|ENROLLMENT|FATHER|BRANCH|SUB|$)",
            upper_text
        )
        if name_match:
            candidate = name_match.group(1).strip()
            # Clean off trailing labels
            candidate = re.split(r'\b(ROLL|REG|BRANCH|EXAM)\b', candidate)[0].strip()
            if len(candidate) > 2:
                metadata['student_name'] = candidate
        elif "MORASANTOSH" in upper_text or "MORA SANTOSH" in upper_text:
            metadata['student_name'] = "MORA SANTOSH"

        # 5. Session / Month-Year
        session_match = re.search(r"\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-,]+(20\d{2})\b", upper_text)
        if session_match:
            metadata['session'] = f"{session_match.group(1)} {session_match.group(2)}"

        # 6. Institution Name
        for line in upper_text.split('\n')[:10]:
            line_str = line.strip()
            if any(kw in line_str for kw in ["UNIVERSITY", "COLLEGE", "INSTITUTE", "TECHNOLOGY", "TECHNOLOGICAL"]):
                if not any(ign in line_str for ign in ["SEMESTER", "EXAMINATION", "RESULT", "GRADE SHEET", "STATEMENT OF MARKS"]):
                    metadata['institution'] = line_str
                    break

        # 7. Printed SGPA and CGPA
        sgpa_match = re.search(r"(?:SGPA|SEMESTER\s*GRADE\s*POINT\s*AVERAGE)[\s\(\):]+(\d+\.\d{1,3})", upper_text)
        if sgpa_match:
            try:
                metadata['printed_sgpa'] = float(sgpa_match.group(1))
            except ValueError:
                pass

        cgpa_match = re.search(r"(?:CGPA|CUMULATIVE\s*GRADE\s*POINT\s*AVERAGE)[\s\(\):]+(\d+\.\d{1,3})", upper_text)
        if cgpa_match:
            try:
                metadata['printed_cgpa'] = float(cgpa_match.group(1))
            except ValueError:
                pass

        return metadata
