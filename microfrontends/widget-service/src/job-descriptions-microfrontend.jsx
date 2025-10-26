// Job Descriptions Microfrontend - Single SPA + JSX
// Using global React objects loaded by the main application
const { useState, useEffect, createElement } = React;
const { createRoot } = ReactDOM;

// Main Job Descriptions Component
const JobDescriptionsMicrofrontend = ({ jobDescriptions = [], user = {} }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredJobs, setFilteredJobs] = useState(jobDescriptions);

  useEffect(() => {
    const filtered = jobDescriptions.filter(job =>
      job.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      job.company.toLowerCase().includes(searchTerm.toLowerCase())
    );
    setFilteredJobs(filtered);
  }, [searchTerm, jobDescriptions]);

  const handleDelete = (jobId) => {
    if (confirm('Are you sure you want to delete this job description?')) {
      console.log('Deleting job:', jobId);
      // In a real app, this would make an API call
      window.location.reload();
    }
  };

  const handleAddNew = () => {
    // Navigate to the Rails new job description page
    window.location.href = '/job_descriptions/new';
  };

  return (
    <div className="job-descriptions-microfrontend">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <div>
          <h2>Job Descriptions</h2>
          <span className="badge bg-primary">
            <i className="fas fa-cube me-1"></i>Single SPA Microfrontend
          </span>
        </div>
        <button 
          className="btn btn-primary"
          onClick={handleAddNew}
        >
          <i className="fas fa-plus me-1"></i>Add New Job Description
        </button>
      </div>

      {/* Search Bar */}
      <div className="row mb-4">
        <div className="col-md-6">
          <div className="input-group">
            <span className="input-group-text">
              <i className="fas fa-search"></i>
            </span>
            <input
              type="text"
              className="form-control"
              placeholder="Search job descriptions..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
        <div className="col-md-6 text-end">
          <small className="text-muted">
            Showing {filteredJobs.length} of {jobDescriptions.length} jobs
          </small>
        </div>
      </div>

      {/* Job Cards */}
      {filteredJobs.length > 0 ? (
        <div className="row">
          {filteredJobs.map((job) => (
            <div key={job.id} className="col-md-6 col-lg-4 mb-4">
              <div className="card h-100 shadow-sm">
                <div className="card-body">
                  <div className="d-flex justify-content-between align-items-start mb-2">
                    <h5 className="card-title">
                      <a href={`/job_descriptions/${job.id}`} className="text-decoration-none">
                        {job.title}
                      </a>
                    </h5>
                    <span className="badge bg-success">Active</span>
                  </div>
                  
                  <h6 className="card-subtitle mb-2 text-muted">
                    <i className="fas fa-building me-1"></i>
                    {job.company}
                  </h6>
                  
                  <p className="card-text">
                    <small className="text-muted">
                      <i className="fas fa-map-marker-alt me-1"></i>
                      {job.location || 'Remote'}
                      <br />
                      <i className="fas fa-briefcase me-1"></i>
                      {job.employment_type || 'Full-time'}
                    </small>
                  </p>
                </div>
                
                <div className="card-footer bg-transparent">
                  <div className="btn-group w-100" role="group">
                    <a href={`/job_descriptions/${job.id}`} className="btn btn-outline-primary btn-sm">
                      View
                    </a>
                    <a href={`/job_descriptions/${job.id}/edit`} className="btn btn-outline-secondary btn-sm">
                      Edit
                    </a>
                    <button 
                      className="btn btn-outline-danger btn-sm"
                      onClick={() => handleDelete(job.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <EmptyState onAddNew={handleAddNew} />
      )}
      
      {/* Microfrontend Info */}
      <div className="mt-4">
        <small className="text-muted">
          <i className="fas fa-info-circle me-1"></i>
          Single SPA Microfrontend • User: {user.email}
        </small>
      </div>
    </div>
  );
};

// Empty State Component
const EmptyState = ({ onAddNew }) => (
  <div className="text-center py-5">
    <div className="mb-3">
      <i className="fas fa-briefcase fa-3x text-muted"></i>
    </div>
    <h4>No job descriptions found</h4>
    <p className="text-muted">Start by adding your first job description to match against resumes.</p>
    <button className="btn btn-primary" onClick={onAddNew}>
      <i className="fas fa-plus me-1"></i>Add Job Description
    </button>
  </div>
);

// Single SPA Lifecycle Functions
let mountedContainer = null;

function bootstrap(props) {
  console.log('Job Descriptions Microfrontend: Bootstrap', props);
  return Promise.resolve();
}

function mount(props) {
  console.log('Job Descriptions Microfrontend: Mount', props);
  
  const container = props.domElement;
  if (!container) {
    return Promise.reject(new Error('No domElement provided'));
  }

  mountedContainer = container;
  const { jobDescriptions = [], user = {} } = props;

  // Create React root and render
  const root = createRoot(container);
  root.render(
    createElement(JobDescriptionsMicrofrontend, {
      jobDescriptions,
      user
    })
  );

  return Promise.resolve();
}

function unmount(props) {
  console.log('Job Descriptions Microfrontend: Unmount');
  
  if (mountedContainer) {
    const root = createRoot(mountedContainer);
    root.unmount();
    mountedContainer = null;
  }
  
  return Promise.resolve();
}

// Export for Single SPA - SystemJS compatible
// Make lifecycle functions available globally
window.jobDescriptionsMicrofrontend = {
  bootstrap,
  mount,
  unmount
};

// Also export as default for ES6 module compatibility
export default {
  bootstrap,
  mount,
  unmount
};

// Export individual functions
export { bootstrap, mount, unmount };