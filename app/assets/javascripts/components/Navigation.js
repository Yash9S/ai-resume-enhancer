const Navigation = (props) => {
  const handleSignOut = (e) => {
    e.preventDefault();
    
    // Get CSRF token from meta tag or hidden input
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content || 
                     document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    
    if (!csrfToken) {
      console.error('CSRF token not found');
      // Fallback to simple navigation
      window.location.href = '/users/sign_out';
      return;
    }
    
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/users/sign_out';
    
    const methodInput = document.createElement('input');
    methodInput.type = 'hidden';
    methodInput.name = '_method';
    methodInput.value = 'delete';
    
    const csrfInput = document.createElement('input');
    csrfInput.type = 'hidden';
    csrfInput.name = 'authenticity_token';
    csrfInput.value = csrfToken;
    
    form.appendChild(methodInput);
    form.appendChild(csrfInput);
    document.body.appendChild(form);
    
    // Add some feedback
    if (window.toast) {
      window.toast.info('Signing out...');
    }
    
    form.submit();
  };

  const { currentUser } = props;
  
  // Check if we're on admin subdomain
  const isAdminSubdomain = () => {
    const host = window.location.host;
    return host.startsWith('all.');
  };
    
  return (
      React.createElement('nav', { className: 'navbar' },
        React.createElement('div', { className: 'navbar-container' },
          React.createElement('div', { className: 'navbar-left' },
            React.createElement('div', { className: 'navbar-brand' },
              React.createElement('a', { href: '/' }, 'AI Resume Parser')
            ),
            React.createElement('div', { className: 'navbar-menu' },
              isAdminSubdomain() && currentUser && currentUser.role === 'admin' ? [
                // Admin subdomain navigation
                React.createElement('a', { key: 'admin-dashboard', href: '/admin/dashboard/index', className: 'navbar-item' }, 'Admin Dashboard'),
                React.createElement('a', { key: 'tenants', href: '/admin/tenants', className: 'navbar-item' }, 'Tenants'),
                React.createElement('a', { key: 'users', href: '/admin/users', className: 'navbar-item' }, 'Users')
              ] : [
                // Regular tenant navigation  
                React.createElement('a', { key: 'dashboard', href: '/', className: 'navbar-item' }, 'Dashboard'),
                React.createElement('a', { key: 'resumes', href: '/resumes', className: 'navbar-item' }, 'Resumes'),
                React.createElement('a', { key: 'job-descriptions', href: '/job_descriptions', className: 'navbar-item' }, 'Job Descriptions')
              ]
            )
          ),
          React.createElement('div', { className: 'navbar-right' },
            currentUser ? [
              React.createElement('span', { key: 'profile', className: 'navbar-profile' }, '👋 ' + currentUser.email),
              React.createElement('button', { 
                key: 'signout',
                onClick: handleSignOut, 
                className: 'navbar-item btn-signout' 
              }, 'Sign Out')
            ] : [
              React.createElement('a', { key: 'login', href: '/users/sign_in', className: 'navbar-item' }, 'Login'),
              React.createElement('a', { key: 'signup', href: '/users/sign_up', className: 'navbar-item' }, 'Sign Up')
            ]
          )
        )
      )
    );
};