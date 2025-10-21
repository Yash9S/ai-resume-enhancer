// app/assets/javascripts/toastr_integration.js
// Integration between React components and toastr notifications

window.showNotification = function(type, message, title = null, options = {}) {
  if (typeof toastr !== 'undefined') {
    const toastrOptions = Object.assign({
      closeButton: true,
      progressBar: true,
      positionClass: 'toast-top-right',
      timeOut: 5000
    }, options);
    
    // Set options for this notification
    toastr.options = toastrOptions;
    
    // Show the notification
    switch(type) {
      case 'success':
        toastr.success(message, title);
        break;
      case 'error':
        toastr.error(message, title);
        break;
      case 'info':
        toastr.info(message, title);
        break;
      case 'warning':
        toastr.warning(message, title);
        break;
      default:
        toastr.info(message, title);
    }
  } else {
    console.warn('Toastr is not available. Message:', message);
  }
};

// Helper functions for React components
window.toast = {
  success: (message, title, options) => showNotification('success', message, title, options),
  error: (message, title, options) => showNotification('error', message, title, options),
  info: (message, title, options) => showNotification('info', message, title, options),
  warning: (message, title, options) => showNotification('warning', message, title, options)
};