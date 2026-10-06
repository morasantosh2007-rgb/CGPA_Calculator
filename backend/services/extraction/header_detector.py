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
        # Roman with SEMESTER e.g., "SEMESTER III", "SEM-III", "III SEMESTER"
        r"(?:SEMESTER|SEM)[\s\-:]+([IVXLCDM]+)\b",
        r"\b([IVXLCDM]+)[\s\-]+(?:SEMESTER|SEM)\b",
        # Degree prefixes like "III B.TECH", "IV B.E", "3-1 B.TECH"
        r"\b([IVXLCDM]+)[\s\-]+B\.?\s*(?:TECH|E|ARCH|SC)\b",
        # Words e.g. "THIRD SEMESTER", "FIRST SEMESTER"
        r"\b(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH)[\s\-]+(?:SEMESTER|SEM)\b",
        # Arabic with SEMESTER e.g. "SEMESTER 3", "3RD SEMESTER"
        r"(?:SEMESTER|SEM)[\s\-:]+(\d{1,2})\b",
        r"\b(\d{1,2})(?:ST|ND|RD|TH)?[\s\-]+(?:SEMESTER|SEM)\b",
        # Year - Sem patterns like "III YEAR I SEM" -> Sem 5, "II-I" -> Sem 3
        r"\b([IVXLCDM]+|\d)[\s\-]+YEAR[\s\-]+([IVXLCDM]+|\d)[\s\-]+SEM\b",
    ]

    EXAM_TYPE_PATTERNS = [
        (r"\bSUPPLEMENTARY(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "SUPPLEMENTARY"),
        (r"\bSUPPLE(?:\s+EXAM|\s+EXAMINATION)?\b", "SUPPLEMENTARY"),
        (r"\bBACKLOG(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "BACKLOG"),
        (r"\bREVALUATION(?:\s+RESULTS?|\s+EXAM)?\b", "REVALUATION"),
        (r"\bRE\-VALUATION\b", "REVALUATION"),
        (r"\bIMPROVEMENT(?:\s+EXAMINATION|\s+EXAM)?\b", "IMPROVEMENT"),
        (r"\bREPEAT(?:\s+EXAM)?\b", "REPEAT"),
        (r"\bREGULAR(?:\s+EXAMINATION|\s+EXAM|\s+RESULTS?)?\b", "REGULAR"),
        (r"\bSEMESTER\s+END\s+EXAMINATION\b", "REGULAR"),
    ]

    DOCUMENT_KEYWORDS = [
        "GRADE SHEET", "STATEMENT OF MARKS", "MARKS MEMORANDUM",
        "PROVISIONAL CERTIFICATE", "TRANSCRIPT", "GRADE CARD",
        "SEMESTER GRADE REPORT", "EXAMINATION RESULTS"
    ]

    @classmethod
    def classify_document(cls, text):
        upper_text = text.upper()
        
        # Check if academic document
        is_academic = any(kw in upper_text for kw in cls.DOCUMENT_KEYWORDS) or \
                      ("SEMESTER" in upper_text and ("GRADE" in upper_text or "CREDIT" in upper_text or "MARKS" in upper_text))

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
        university and session from the header text.
        """
        upper_text = text.upper()
        metadata = {
            'document_type': cls.classify_document(text),
            'semester': None,
            'semester_confidence': 0.0,
            'exam_type': 'REGULAR',
            'raw_exam_type': 'REGULAR',
            'exam_type_confidence': 0.50,
            'student_name': '',
            'registration_number': '',
            'session': '',
            'institution': '',
        }

        # 1. Semester Identification
        for pattern in cls.SEMESTER_REGEXES:
            match = re.search(pattern, upper_text)
            if match:
                groups = match.groups()
                if len(groups) == 1:
                    raw_val = groups[0]
                    if raw_val in cls.ROMAN_MAP:
                        metadata['semester'] = cls.ROMAN_MAP[raw_val]
                        metadata['semester_confidence'] = 0.96
                        break
                    elif raw_val.isdigit():
                        metadata['semester'] = int(raw_val)
                        metadata['semester_confidence'] = 0.95
                        break
                elif len(groups) == 2:
                    # Year-Sem pattern e.g. "III YEAR I SEM" -> (3-1)*2 + 1 = Sem 5
                    y_val = cls.ROMAN_MAP.get(groups[0], int(groups[0]) if groups[0].isdigit() else 1)
                    s_val = cls.ROMAN_MAP.get(groups[1], int(groups[1]) if groups[1].isdigit() else 1)
                    metadata['semester'] = (y_val - 1) * 2 + s_val
                    metadata['semester_confidence'] = 0.94
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
            r"(?:REG(?:ISTRATION)?\.?\s*(?:NO|NUMBER)?|ROLL\s*(?:NO|NUMBER)?|HT\s*NO|HTNO|PIN|ENROLLMENT(?:\s*NO)?)[\s\-:]+([A-Z0-9]{6,18})\b",
            upper_text
        )
        if reg_match:
            metadata['registration_number'] = reg_match.group(1).strip()

        # 4. Student Name (stops before multiple spaces, newline, or next header field)
        name_match = re.search(
            r"(?:STUDENT|CANDIDATE)?\s*NAME[\s\-:]+([A-Z\s\.]{3,50}?)(?:\s{2,}|\n|\r|REG|ROLL|HT|HALL|PIN|ENROLLMENT|FATHER|BRANCH|$)",
            upper_text
        )
        if name_match:
            metadata['student_name'] = name_match.group(1).strip()

        # 5. Session / Month-Year
        session_match = re.search(r"\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-,]+(20\d{2})\b", upper_text)
        if session_match:
            metadata['session'] = f"{session_match.group(1)} {session_match.group(2)}"

        # 6. Institution Name
        for line in upper_text.split('\n')[:8]:
            line_str = line.strip()
            if any(kw in line_str for kw in ["UNIVERSITY", "COLLEGE", "INSTITUTE", "TECHNOLOGICAL"]):
                if not any(ign in line_str for ign in ["SEMESTER", "EXAMINATION", "RESULT", "GRADE SHEET", "STATEMENT OF MARKS"]):
                    metadata['institution'] = line_str
                    break

        return metadata
