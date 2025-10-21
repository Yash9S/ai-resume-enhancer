const Dashboard = (props) => {
  const [stats, setStats] = React.useState({
    total_resumes: 0,
    processed_resumes: 0,
    total_job_descriptions: 0,
    successful_processings: 0
  });
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    // Use props data if available, otherwise fetch from API
    if (props.stats) {
      setStats(props.stats);
      setLoading(false);
    } else {
      fetchDashboardData();
    }
  }, [props.stats]);

  const fetchDashboardData = async () => {
    try {
      const response = await fetch('/dashboard', {
        method: 'GET',
        credentials: 'same-origin', // Include session cookies
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        setStats(data.dashboard?.resumes?.stats || stats);
        // Show success notification only if we actually loaded new data
        if (window.toast && !props.stats) {
          window.toast.success('Dashboard data loaded successfully!');
        }
      } else if (response.status === 401) {
        // Handle authentication error quietly
        console.log('Authentication required for API endpoint');
      } else {
        // Show error notification only for unexpected errors
        if (window.toast) {
          window.toast.error('Failed to load dashboard data');
        }
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      // Show error notification only for network errors
      if (window.toast) {
        window.toast.error('Network error while loading dashboard');
      }
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      React.createElement('div', { className: 'loading-spinner' },
        React.createElement('div', { className: 'spinner' }),
        React.createElement('p', null, 'Loading dashboard...')
      )
    );
  }

  return (
      React.createElement('div', { className: 'dashboard' },
        React.createElement('div', { className: 'hero-section' },
          React.createElement('h1', null, 'Welcome to AI Resume Parser'),
          React.createElement('p', null, 'Enhance your career with AI-powered resume analysis')
        ),
        React.createElement('div', { className: 'stats-grid' },
          React.createElement('div', { className: 'stat-card primary' },
            React.createElement('h3', null, stats.total_resumes),
            React.createElement('p', null, 'Total Resumes')
          ),
          React.createElement('div', { className: 'stat-card success' },
            React.createElement('h3', null, stats.processed_resumes),
            React.createElement('p', null, 'Processed Resumes')
          ),
          React.createElement('div', { className: 'stat-card info' },
            React.createElement('h3', null, stats.total_job_descriptions),
            React.createElement('p', null, 'Job Descriptions')
          ),
          React.createElement('div', { className: 'stat-card warning' },
            React.createElement('h3', null, stats.successful_processings),
            React.createElement('p', null, 'Successful Processings')
          )
        ),
        React.createElement('div', { className: 'quick-actions' },
          React.createElement('h2', null, '🚀 Quick Actions'),
          React.createElement('div', { className: 'action-buttons' },
            React.createElement('a', { href: '/resumes/new', className: 'btn btn-primary' }, '📄 Upload New Resume'),
            React.createElement('a', { href: '/job_descriptions/new', className: 'btn btn-secondary' }, '💼 Add Job Description'),
            React.createElement('a', { href: '/resumes', className: 'btn btn-outline' }, '📊 View All Resumes')
          )
        )
      )
    );
};