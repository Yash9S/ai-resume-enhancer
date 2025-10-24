// Job Descriptions Microfrontend - JSX + React Router
import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Link, useNavigate } from 'react-router-dom';

// Main Job Descriptions Component
const JobDescriptionsList = ({ jobDescriptions, user }) => {
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredJobs, setFilteredJobs] = useState(jobDescriptions);

  useEffect(() => {
    const filtered = jobDescriptions.filter(job =>
      job.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      job.company.toLowerCase().includes(searchTerm.toLowerCase())
    );
    setFilteredJobs(filtered);
  }, [searchTerm, jobDescriptions]);

  return (
    <div className="job-descriptions-microfrontend">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <div>
          <h2>Job Descriptions</h2>
          <span className="badge bg-primary">
            <i className="fas fa-cube me-1"></i>React Microfrontend
          </span>
        </div>
        <button 
          className="btn btn-primary"
          onClick={() => navigate('/new')}
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
                      <Link 
                        to={`/job/${job.id}`} 
                        className="text-decoration-none"
                      >
                        {job.title}
                      </Link>
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
                    <Link 
                      to={`/job/${job.id}`}
                      className="btn btn-outline-primary btn-sm"
                    >
                      View
                    </Link>
                    <Link 
                      to={`/job/${job.id}/edit`}
                      className="btn btn-outline-secondary btn-sm"
                    >
                      Edit
                    </Link>
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
        <EmptyState onAddNew={() => navigate('/new')} />
      )}
      
      {/* Microfrontend Info */}
      <div className="mt-4">
        <small className="text-muted">
          <i className="fas fa-info-circle me-1"></i>
          Microfrontend running on React Router • User: {user.email}
        </small>
      </div>
    </div>
  );

  function handleDelete(jobId) {
    if (confirm('Are you sure you want to delete this job description?')) {
      // This would typically make an API call
      console.log('Deleting job:', jobId);
      // For now, just navigate back
      window.location.reload();
    }
  }
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

// Job Details Component (for routing)
const JobDetails = ({ jobId }) => (
  <div className="job-details">
    <div className="d-flex justify-content-between align-items-center mb-4">
      <h3>Job Details #{jobId}</h3>
      <Link to="/" className="btn btn-outline-secondary">
        <i className="fas fa-arrow-left me-1"></i>Back to List
      </Link>
    </div>
    <div className="alert alert-info">
      <strong>Microfrontend Route:</strong> This is a separate route within the Job Descriptions microfrontend.
      In a real implementation, this would show job details loaded from an API.
    </div>
  </div>
);

// Add New Job Component (for routing)
const AddNewJob = () => {
  const navigate = useNavigate();
  
  return (
    <div className="add-job">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h3>Add New Job Description</h3>
        <button className="btn btn-outline-secondary" onClick={() => navigate('/')}>
          <i className="fas fa-arrow-left me-1"></i>Back to List
        </button>
      </div>
      <div className="alert alert-info">
        <strong>Microfrontend Route:</strong> This is the "Add New" route within the microfrontend.
        In a real implementation, this would have a form to create new job descriptions.
      </div>
      <button className="btn btn-primary" onClick={() => navigate('/')}>
        Cancel
      </button>
    </div>
  );
};

// Main App with Router
const JobDescriptionsMicrofrontend = ({ jobDescriptions, user }) => {
  return (
    <BrowserRouter basename="/job_descriptions">
      <Routes>
        <Route 
          path="/" 
          element={
            <JobDescriptionsList 
              jobDescriptions={jobDescriptions} 
              user={user} 
            />
          } 
        />
        <Route path="/job/:jobId" element={<JobDetails />} />
        <Route path="/job/:jobId/edit" element={<JobDetails />} />
        <Route path="/new" element={<AddNewJob />} />
      </Routes>
    </BrowserRouter>
  );
};

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
  const root = ReactDOM.createRoot(container);
  root.render(
    React.createElement(JobDescriptionsMicrofrontend, {
      jobDescriptions,
      user
    })
  );

  return Promise.resolve();
}

function unmount(props) {
  console.log('Job Descriptions Microfrontend: Unmount');
  
  if (mountedContainer) {
    const root = ReactDOM.createRoot(mountedContainer);
    root.unmount();
    mountedContainer = null;
  }
  
  return Promise.resolve();
}

// Auto-register with Single SPA - Direct execution without IIFE
console.log('🚀 Loading Job Descriptions Microfrontend...');

// Registration function
async function registerJobDescriptionsMicrofrontend() {
  try {
    // Check if we're in a Single SPA environment
    if (typeof System !== 'undefined' && System.import) {
      const { registerApplication, start } = await System.import('single-spa');
      
      // Register this microfrontend
      registerApplication({
        name: 'job-descriptions-app',
        app: () => Promise.resolve({ bootstrap, mount, unmount }),
        activeWhen: () => window.location.pathname.includes('/job_descriptions'),
        customProps: () => {
          const container = document.getElementById('job-descriptions-microfrontend');
          
          // Extract Rails data from the container's data attributes
          const jobDescriptionsData = container?.dataset?.jobDescriptions;
          const userData = container?.dataset?.user;
          
          return {
            domElement: container,
            jobDescriptions: jobDescriptionsData ? JSON.parse(jobDescriptionsData) : [],
            user: userData ? JSON.parse(userData) : { email: 'unknown', role: 'user' }
          };
        }
      });
      
      start();
      console.log('✅ Job Descriptions Microfrontend registered!');
    }
  } catch (error) {
    console.error('❌ Microfrontend registration failed:', error);
    const container = document.getElementById('job-descriptions-microfrontend');
    if (container) {
      container.innerHTML = 
        '<div class="alert alert-danger">Microfrontend failed to load. Please refresh the page.</div>';
    }
  }
}

// Execute registration when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', registerJobDescriptionsMicrofrontend);
} else {
  registerJobDescriptionsMicrofrontend();
}

// SystemJS Export for Single SPA
if (typeof System !== 'undefined') {
  System.register(['react', 'react-dom', 'react-router-dom'], function() {
    return {
      execute: function() {
        this.default = { bootstrap, mount, unmount };
        this.bootstrap = bootstrap;
        this.mount = mount;
        this.unmount = unmount;
      }
    };
  });
} else if (typeof module !== 'undefined' && module.exports) {
  module.exports = { bootstrap, mount, unmount };
} else {
  window.jobDescriptionsMicrofrontend = { bootstrap, mount, unmount };
}