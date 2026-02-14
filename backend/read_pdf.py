import PyPDF2

pdf_path = "e:/mobileapp/lot inward print format.pdf"

try:
    with open(pdf_path, 'rb') as f:
        reader = PyPDF2.PdfReader(f)
        text = ""
        for page in reader.pages:
            text += page.extract_text() + "\n"
        print(text)
except Exception as e:
    print(f"Error reading PDF: {e}")
