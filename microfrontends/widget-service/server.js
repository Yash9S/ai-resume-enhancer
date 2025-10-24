const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4005;

app.use(cors());
app.use(express.static(path.join(__dirname, 'src')));

// Serve the job descriptions microfrontend (working JavaScript version)
app.get('/job-descriptions-widget.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  
  // Working JavaScript microfrontend (no JSX conversion needed)
  const workingMicrofrontend = `
console.log('🚀 Loading Job Descriptions Microfrontend...');

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
  
  // Create the UI with vanilla JavaScript (no JSX issues)
  container.innerHTML = \`
    <div class="job-descriptions-microfrontend">
      <div class="card border-0 bg-primary text-white shadow mb-4">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <h4 class="mb-0">
              <i class="fas fa-briefcase me-2"></i>Job Descriptions Microfrontend
            </h4>
            <span class="badge bg-light text-primary">
              <i class="fas fa-cube me-1"></i>SystemJS + Single SPA
            </span>
          </div>
          
          <p class="mb-3">
            <strong>User:</strong> \${user.email || 'Unknown'} (\${user.role || 'user'})<br>
            <strong>Total Jobs:</strong> \${jobDescriptions.length}
          </p>

          <div class="row">
            \${jobDescriptions.length > 0 ? 
              jobDescriptions.slice(0, 6).map(job => \`
                <div class="col-md-6 col-lg-4 mb-3">
                  <div class="bg-white bg-opacity-20 rounded p-3">
                    <div class="fw-bold text-white mb-1">\${job.title}</div>
                    <div class="small text-light">\${job.company}</div>
                    <div class="small text-light opacity-75">
                      <i class="fas fa-map-marker-alt"></i> \${job.location || 'Remote'}
                    </div>
                    <div class="small text-light opacity-75">
                      <i class="fas fa-briefcase"></i> \${job.employment_type || 'Full-time'}
                    </div>
                  </div>
                </div>
              \`).join('') : 
              '<div class="col-12 text-center"><p class="text-light">No job descriptions yet</p></div>'
            }
          </div>

          <div class="text-center mt-3">
            <button class="btn btn-light btn-sm me-2" onclick="alert('Add New Job - Microfrontend Action')">
              <i class="fas fa-plus me-1"></i>Add Job
            </button>
            <button class="btn btn-outline-light btn-sm" onclick="alert('Search Jobs - Microfrontend Feature')">
              <i class="fas fa-search me-1"></i>Search
            </button>
          </div>
          
          <div class="text-center mt-3">
            <small class="text-light opacity-75">
              <i class="fas fa-server me-1"></i>
              Served from port 4005 • No IIFE • SystemJS ImportMap
            </small>
          </div>
        </div>
      </div>
      
      <div class="alert alert-success">
        <strong>✅ Microfrontend Features Working:</strong>
        <ul class="mb-0 mt-2">
          <li>✅ SystemJS ImportMap resolution</li>
          <li>✅ Single SPA registerApplication</li>
          <li>✅ Data from Rails via attributes</li>
          <li>✅ Containerized service (Docker)</li>
          <li>✅ No IIFE - Clean named functions</li>
        </ul>
      </div>
    </div>
  \`;
  
  return Promise.resolve();
}

function unmount(props) {
  console.log('Job Descriptions Microfrontend: Unmount');
  
  if (mountedContainer) {
    mountedContainer.innerHTML = '';
    mountedContainer = null;
  }
  
  return Promise.resolve();
}

// Auto-register with Single SPA when loaded (removed for manual registration)
// Registration is now handled in the Rails view for better control

// SystemJS Export for Single SPA
if (typeof System !== 'undefined') {
  System.register([], function(exports) {
    return {
      execute: function() {
        // Export the lifecycle functions using the exports function
        exports('bootstrap', bootstrap);
        exports('mount', mount);
        exports('unmount', unmount);
        exports('default', { bootstrap, mount, unmount });
      }
    };
  });
} else if (typeof module !== 'undefined' && module.exports) {
  module.exports = { bootstrap, mount, unmount };
} else {
  // Global fallback
  window.jobDescriptionsMicrofrontend = { bootstrap, mount, unmount };
}
  `;
  
  res.send(workingMicrofrontend);
});

// Serve the original dashboard widget (for backward compatibility)
app.get('/dashboard-widget.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.sendFile(path.join(__dirname, 'src', 'dashboard-widget.js'));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'job-descriptions-microfrontend',
    endpoints: ['/job-descriptions-widget.js', '/dashboard-widget.js']
  });
});

// Root endpoint  
app.get('/', (req, res) => {
  res.json({
    name: 'Job Descriptions Microfrontend Service',
    endpoints: {
      'job-descriptions': '/job-descriptions-widget.js',
      'dashboard-widget': '/dashboard-widget.js'
    },
    features: ['Single SPA', 'SystemJS ImportMap', 'React Router', 'JSX Ready']
  });
});

app.listen(PORT, () => {
  console.log(`Dashboard Widget Service running on port ${PORT}`);
});