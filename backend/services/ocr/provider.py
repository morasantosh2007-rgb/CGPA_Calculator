import os
import shutil
import pypdf
from PIL import Image

class OCRProvider:
    """Base abstract provider for OCR engines."""
    def extract_text(self, file_path_or_bytes):
        raise NotImplementedError

    def extract_layout(self, file_path_or_bytes):
        raise NotImplementedError

class TesseractOCRProvider(OCRProvider):
    """Tesseract implementation with pytesseract."""
    def __init__(self):
        import pytesseract
        self.pytesseract = pytesseract
        # Check standard binary locations
        tess_candidates = [
            shutil.which('tesseract'),
            r"C:\Program Files\Tesseract-OCR\tesseract.exe",
            r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
            os.path.expanduser(r"~\AppData\Local\Programs\Tesseract-OCR\tesseract.exe")
        ]
        for candidate in tess_candidates:
            if candidate and os.path.exists(candidate):
                self.pytesseract.pytesseract.tesseract_cmd = candidate
                break

    def extract_text(self, image_input):
        try:
            if isinstance(image_input, str):
                image = Image.open(image_input)
            else:
                image = image_input
            return self.pytesseract.image_to_string(image)
        except Exception as e:
            return ""

    def extract_data_boxes(self, image_input):
        try:
            if isinstance(image_input, str):
                image = Image.open(image_input)
            else:
                image = image_input
            return self.pytesseract.image_to_data(image, output_type=self.pytesseract.Output.DICT)
        except Exception:
            return {}

import io

class DigitalPDFProvider(OCRProvider):
    """Extracts text streams and layout from digital PDFs, with embedded image fallback."""
    def extract_pages(self, pdf_path, tesseract_provider=None):
        try:
            reader = pypdf.PdfReader(pdf_path)
            pages = []
            for page_idx, page in enumerate(reader.pages):
                txt = (page.extract_text() or "").strip()
                if not txt and tesseract_provider and hasattr(page, 'images') and page.images:
                    img_texts = []
                    for img_obj in page.images:
                        try:
                            pil_img = Image.open(io.BytesIO(img_obj.data))
                            img_txt = tesseract_provider.extract_text(pil_img)
                            if img_txt and img_txt.strip():
                                img_texts.append(img_txt.strip())
                        except Exception:
                            continue
                    txt = "\n".join(img_texts).strip()

                pages.append({
                    'page_number': page_idx + 1,
                    'text': txt
                })
            return pages
        except Exception:
            return []

    def extract_text(self, pdf_path, tesseract_provider=None):
        pages = self.extract_pages(pdf_path, tesseract_provider)
        full_text = []
        for p in pages:
            if p['text']:
                full_text.append(f"--- PAGE {p['page_number']} ---\n{p['text']}")
        return "\n\n".join(full_text)

class HybridOCRProvider(OCRProvider):
    """
    Intelligent Hybrid OCR Engine:
    1. If file is a digital PDF with embedded text, extract high-fidelity text streams per page.
    2. If scanned PDF, extract embedded images and process with OCR.
    3. If image and Tesseract is present, run Tesseract.
    4. Fallback gracefully with confidence estimation.
    """
    def __init__(self):
        self.pdf_provider = DigitalPDFProvider()
        try:
            self.tesseract_provider = TesseractOCRProvider()
        except Exception:
            self.tesseract_provider = None

    def extract_document(self, file_path):
        ext = os.path.splitext(file_path)[-1].lower()
        if ext == '.pdf':
            pages_data = self.pdf_provider.extract_pages(file_path, tesseract_provider=self.tesseract_provider)
            pdf_text = "\n\n".join([f"--- PAGE {p['page_number']} ---\n{p['text']}" for p in pages_data if p['text']])
            if len(pdf_text.strip()) > 30:
                return {
                    'text': pdf_text,
                    'pages': pages_data,
                    'provider': 'DigitalPDFProvider',
                    'confidence': 0.98
                }
            elif len(pdf_text.strip()) > 0:
                return {
                    'text': pdf_text,
                    'pages': pages_data,
                    'provider': 'PDFScannedOCRProvider',
                    'confidence': 0.85
                }
            return {
                'text': "",
                'pages': [],
                'provider': 'PDFProvider',
                'confidence': 0.50
            }

        # Image processing
        if self.tesseract_provider:
            tess_text = self.tesseract_provider.extract_text(file_path)
            if len(tess_text.strip()) > 20:
                return {
                    'text': tess_text,
                    'provider': 'TesseractOCRProvider',
                    'confidence': 0.88
                }

        # If image cannot be read by tesseract, return fallback
        return {
            'text': "",
            'provider': 'FallbackProvider',
            'confidence': 0.50
        }
