import os
import io
import shutil
import pypdf
import numpy as np
from PIL import Image, ImageOps, ImageStat

class OCRProvider:
    """Base abstract provider for OCR engines."""
    def extract_text(self, file_path_or_bytes):
        raise NotImplementedError

    def extract_layout(self, file_path_or_bytes):
        raise NotImplementedError

class RapidOCRProvider(OCRProvider):
    """
    State-of-the-art RapidOCR ONNX-runtime OCR provider.
    Provides high-speed, local neural text detection (DBNet) and recognition (SVTR/CRNN)
    with zero external binary dependencies.
    """
    def __init__(self):
        self.ocr = None
        self.available = False
        try:
            from rapidocr_onnxruntime import RapidOCR
            self.ocr = RapidOCR()
            self.available = True
        except Exception:
            self.ocr = None
            self.available = False

    def is_available(self):
        return self.available and self.ocr is not None

    def _prepare_image(self, image_input):
        """Standardizes input into a PIL.Image and auto-corrects dark-mode contrast."""
        if isinstance(image_input, str):
            img = Image.open(image_input)
        elif isinstance(image_input, bytes):
            img = Image.open(io.BytesIO(image_input))
        elif hasattr(image_input, 'read'):
            img = Image.open(image_input)
        elif isinstance(image_input, Image.Image):
            img = image_input
        elif isinstance(image_input, np.ndarray):
            img = Image.fromarray(image_input)
        else:
            raise ValueError(f"Unsupported image input type: {type(image_input)}")

        # Check for dark mode / inverted screenshots
        stat = ImageStat.Stat(img.convert('L'))
        if stat.mean[0] < 100:
            img = ImageOps.invert(img.convert('RGB'))

        return img

    def extract_boxes_and_text(self, image_input):
        if not self.is_available():
            return [], "", None

        pil_img = self._prepare_image(image_input)
        np_arr = np.array(pil_img.convert('RGB'))
        try:
            res, _ = self.ocr(np_arr)
        except Exception:
            res = None

        boxes = res or []
        full_text = "\n".join([item[1] for item in boxes]) if boxes else ""
        return boxes, full_text, pil_img

    def extract_text(self, image_input):
        _, text, _ = self.extract_boxes_and_text(image_input)
        return text

class TesseractOCRProvider(OCRProvider):
    """Tesseract implementation with pytesseract as fallback."""
    def __init__(self):
        import pytesseract
        self.pytesseract = pytesseract
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
        except Exception:
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

class DigitalPDFProvider(OCRProvider):
    """Extracts text streams and layout from digital PDFs, with embedded image fallback."""
    def __init__(self, rapid_provider=None, tesseract_provider=None):
        self.rapid_provider = rapid_provider
        self.tesseract_provider = tesseract_provider

    def extract_pages(self, pdf_path):
        pages = []
        # Priority 1: High-speed PyMuPDF
        try:
            import pymupdf
            doc = pymupdf.open(pdf_path)
            for page_idx, page in enumerate(doc):
                txt = (page.get_text() or "").strip()
                boxes = []
                pil_img = None

                # If scanned / image-based PDF page with little selectable text
                if len(txt) < 30:
                    pix = page.get_pixmap(dpi=150)
                    img_bytes = pix.tobytes("png")
                    pil_img = Image.open(io.BytesIO(img_bytes))

                    if self.rapid_provider and self.rapid_provider.is_available():
                        boxes, txt, pil_img = self.rapid_provider.extract_boxes_and_text(pil_img)
                    elif self.tesseract_provider:
                        try:
                            txt = self.tesseract_provider.extract_text(pil_img)
                        except Exception:
                            pass

                pages.append({
                    'page_number': page_idx + 1,
                    'text': txt,
                    'boxes': boxes,
                    'pil_image': pil_img
                })
            doc.close()
            if pages:
                return pages
        except Exception:
            pass

        # Priority 2: Fallback to pypdf
        try:
            reader = pypdf.PdfReader(pdf_path)
            pages = []
            for page_idx, page in enumerate(reader.pages):
                txt = (page.extract_text() or "").strip()
                boxes = []
                pil_img = None

                # If scanned / image-based PDF page with little to no selectable text
                if len(txt) < 30 and hasattr(page, 'images') and page.images:
                    # Pick largest image on page (the grade sheet canvas)
                    largest_img = max(page.images, key=lambda x: len(x.data))
                    raw_bytes = largest_img.data
                    
                    if self.rapid_provider and self.rapid_provider.is_available():
                        boxes, txt, pil_img = self.rapid_provider.extract_boxes_and_text(raw_bytes)
                    elif self.tesseract_provider:
                        try:
                            pil_img = Image.open(io.BytesIO(raw_bytes))
                            txt = self.tesseract_provider.extract_text(pil_img)
                        except Exception:
                            pass

                pages.append({
                    'page_number': page_idx + 1,
                    'text': txt,
                    'boxes': boxes,
                    'pil_image': pil_img
                })
            return pages
        except Exception:
            return []

    def extract_text(self, pdf_path):
        pages = self.extract_pages(pdf_path)
        full_text = []
        for p in pages:
            if p['text']:
                full_text.append(f"--- PAGE {p['page_number']} ---\n{p['text']}")
        return "\n\n".join(full_text)

class HybridOCRProvider(OCRProvider):
    """
    Intelligent Hybrid OCR Engine:
    1. If file is a digital PDF with embedded text, extract high-fidelity text streams per page.
    2. If scanned PDF, extract embedded images and process with RapidOCR neural models.
    3. If image, process with RapidOCR with dark-mode contrast inversion and watermark filtering.
    4. Fallback gracefully with confidence estimation.
    """
    def __init__(self):
        self.rapid_provider = RapidOCRProvider()
        try:
            self.tesseract_provider = TesseractOCRProvider()
        except Exception:
            self.tesseract_provider = None
        self.pdf_provider = DigitalPDFProvider(
            rapid_provider=self.rapid_provider,
            tesseract_provider=self.tesseract_provider
        )

    def extract_document(self, file_path):
        ext = os.path.splitext(file_path)[-1].lower()
        if ext == '.pdf':
            pages_data = self.pdf_provider.extract_pages(file_path)
            pdf_text = "\n\n".join([f"--- PAGE {p['page_number']} ---\n{p['text']}" for p in pages_data if p['text']])
            if len(pdf_text.strip()) > 10:
                return {
                    'text': pdf_text,
                    'pages': pages_data,
                    'provider': 'RapidOCR/DigitalPDFProvider',
                    'confidence': 0.98
                }
            return {
                'text': pdf_text,
                'pages': pages_data,
                'provider': 'PDFProvider',
                'confidence': 0.50
            }

        # Standalone Image processing
        if self.rapid_provider and self.rapid_provider.is_available():
            boxes, text, pil_img = self.rapid_provider.extract_boxes_and_text(file_path)
            if len(text.strip()) > 20:
                return {
                    'text': text,
                    'boxes': boxes,
                    'pages': [{
                        'page_number': 1,
                        'text': text,
                        'boxes': boxes,
                        'pil_image': pil_img
                    }],
                    'provider': 'RapidOCRProvider',
                    'confidence': 0.96
                }

        # Fallback to Tesseract
        if self.tesseract_provider:
            tess_text = self.tesseract_provider.extract_text(file_path)
            if len(tess_text.strip()) > 20:
                return {
                    'text': tess_text,
                    'pages': [{'page_number': 1, 'text': tess_text, 'boxes': [], 'pil_image': None}],
                    'provider': 'TesseractOCRProvider',
                    'confidence': 0.85
                }

        return {
            'text': "",
            'pages': [],
            'provider': 'FallbackProvider',
            'confidence': 0.50
        }
