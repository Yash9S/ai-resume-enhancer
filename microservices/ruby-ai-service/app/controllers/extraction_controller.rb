class ExtractionController < ApplicationController
  def structured
    unless params[:file].present?
      return render json: { error: 'No file provided' }, status: :bad_request
    end

    provider = params[:provider] || 'ollama'

    begin
      # Extract text from file
      text = PdfExtractor.new.extract_text(params[:file])

      if text.blank?
        return render json: {
          error: 'Could not extract text from file',
          provider_used: 'none'
        }, status: :unprocessable_entity
      end

      # Ai extraction process
      result = AiProcessor.new.extract_structured_data(text, provider: provider)

      render json: {
        success: result[:success],
        structured_data: result[:structured_data],
        provider_used: result[:provider_used],
        confidence_score: result[:confidence_score],
        original_text: text,
        file_info: {
          filename: params[:file].original_filename,
          size: params[:file].size,
          type: params[:file].content_type
        }
      }

    rescue => e
      Rails.logger.error "Extraction Failed: #{e.message}"
      render json: {
        error: "Extraction failed: #{e.message}",
        provider_used: provider
      }, status: :internal_server_error
    end
  end

  def text
    unless params[:file].present?
      return render json: { error: 'No file provided' }, status: :bad_request
    end

    begin
      text = PdfExtractor.new.extract_text(params[:file])

      render json: {
        success: true,
        text: text,
        file_info: {
          filename: params[:file].original_filename,
          size: params[:file].size,
          type: params[:file].content_type
        }
      }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end