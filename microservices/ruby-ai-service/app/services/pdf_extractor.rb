require 'pdf/reader'
require 'docx'

class PdfExtractor
  def extract_text(file)
    return nil unless file

    case file.content_type
    when 'application/pdf'
      extract_from_pdf(file)
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_from_docx(file)
    when 'text/plain'
      file.read
    else
      raise "Unsupported file type: #{file.content_type}"
    end
  end

  private

  def extract_from_pdf(file)
    reader = PDF::Reader.new(file.tempfile)
    text = reader.pages.map(&:text).join("\n")
    text.strip
  rescue => e
    Rails.logger.error "PDF extraction failed: #{e.message}"
    raise "Failed to extract text from PDF: #{e.message}"
  end

  def extract_from_docx(file)
    doc = Docx::Document.open(file.tempfile)
    doc.paragraphs.map(&:text).join("\n").strip
  rescue => e
    Rails.logger.error "DOCX extraction failed: #{e.message}"
    raise "Failed to extract text from DOCX: #{e.message}"
  end
end