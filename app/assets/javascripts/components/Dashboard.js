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
      <div className="loading-spinner">
        <div className="spinner" />
        <p>Loading dashboard...</p>
      </div>
    );
  }

  return (
    <div className="dashboard">
      <div className="hero-section">
        <h1>Welcome to AI Resume Parser</h1>
        <p>Enhance your career with AI-powered resume analysis</p>
      </div>
      
      <div className="stats-grid">
        <div className="stat-card primary">
          <h3>{stats.total_resumes}</h3>
          <p>Total Resumes</p>
        </div>
        <div className="stat-card success">
          <h3>{stats.processed_resumes}</h3>
          <p>Processed Resumes</p>
        </div>
        <div className="stat-card info">
          <h3>{stats.total_job_descriptions}</h3>
          <p>Job Descriptions</p>
        </div>
        <div className="stat-card warning">
          <h3>{stats.successful_processings}</h3>
          <p>Successful Processings</p>
        </div>
      </div>
      
      <div className="quick-actions">
        <h2>🚀 Quick Actions</h2>
        <div className="action-buttons">
          <a href="/resumes/new" className="btn btn-primary">📄 Upload New Resume</a>
          <a href="/job_descriptions/new" className="btn btn-secondary">💼 Add Job Description</a>
          <a href="/resumes" className="btn btn-outline">📊 View All Resumes</a>
        </div>
      </div>
    </div>
  );
};