# app/helpers/toastr_helper.rb
module ToastrHelper
  def toastr_flash
    flash.each_with_object([]) do |(type, message), flash_messages|
      type = 'success' if type == 'notice'
      type = 'error'   if type == 'alert'
      
      text = escape_javascript(message)
      script = "toastr.#{type}('#{text}');"
      flash_messages << script.html_safe
    end
  end

  def toastr_success(message)
    content_for :toastr do
      javascript_tag "toastr.success('#{escape_javascript(message)}');"
    end
  end

  def toastr_error(message)
    content_for :toastr do
      javascript_tag "toastr.error('#{escape_javascript(message)}');"
    end
  end

  def toastr_info(message)
    content_for :toastr do
      javascript_tag "toastr.info('#{escape_javascript(message)}');"
    end
  end

  def toastr_warning(message)
    content_for :toastr do
      javascript_tag "toastr.warning('#{escape_javascript(message)}');"
    end
  end
end