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
    <nav className="navbar">
      <div className="navbar-container">
        <div className="navbar-left">
          <div className="navbar-brand">
            <a href="/">AI Resume Parser</a>
          </div>
          <div className="navbar-menu">
            {isAdminSubdomain() && currentUser && currentUser.role === 'admin' ? (
              <>
                <a href="/admin/dashboard/index" className="navbar-item">Admin Dashboard</a>
                <a href="/admin/tenants" className="navbar-item">Tenants</a>
                <a href="/admin/users" className="navbar-item">Users</a>
              </>
            ) : (
              <>
                <a href="/" className="navbar-item">Dashboard</a>
                <a href="/resumes" className="navbar-item">Resumes</a>
                <a href="/job_descriptions" className="navbar-item">Job Descriptions</a>
              </>
            )}
          </div>
        </div>
        <div className="navbar-right">
          {currentUser ? (
            <>
              <span className="navbar-profile">👋 {currentUser.email}</span>
              <button onClick={handleSignOut} className="navbar-item btn-signout">
                Sign Out
              </button>
            </>
          ) : (
            <>
              <a href="/users/sign_in" className="navbar-item">Login</a>
              <a href="/users/sign_up" className="navbar-item">Sign Up</a>
            </>
          )}
        </div>
      </div>
    </nav>
  );
};