// Simple Job Descriptions Widget - Single SPA
let mountedContainer = null;

// Single SPA lifecycle: bootstrap
function bootstrap(props) {
  console.log('Job Descriptions Widget: Bootstrap called', props);
  return Promise.resolve();
}

// Single SPA lifecycle: mount
function mount(props) {
  console.log('Job Descriptions Widget: Mount called', props);
  
  const container = props.domElement;
  if (!container) {
    return Promise.reject(new Error('No domElement provided in props'));
  }

  mountedContainer = container;
  const jobDescriptions = props.jobDescriptions || [];
  const user = props.user || {};
  
  container.innerHTML = `
    <div class="card border-0 bg-success text-white shadow">
      <div class="card-body p-3">
        <div class="d-flex justify-content-between align-items-center mb-2">
          <h5 class="mb-0">
            <i class="fas fa-briefcase me-2"></i>Job Descriptions
          </h5>
          <span class="badge bg-light text-success">
            <i class="fas fa-cube me-1"></i>Single SPA
          </span>
        </div>
        
        <p class="small mb-3">
          <strong>User:</strong> ${user.email || 'Unknown'} (${user.role || 'user'})<br>
          <strong>Total Jobs:</strong> ${jobDescriptions.length}
        </p>

        <div class="row">
          ${jobDescriptions.length > 0 ? 
            jobDescriptions.slice(0, 2).map(job => `
              <div class="col-md-6 mb-2">
                <div class="bg-white bg-opacity-20 rounded p-2">
                  <div class="fw-bold small">${job.title}</div>
                  <div class="small text-light">${job.company}</div>
                </div>
              </div>
            `).join('') : 
            '<div class="col-12 text-center"><small>No job descriptions yet</small></div>'
          }
        </div>

        <div class="text-center mt-2">
          <small><i class="fas fa-server me-1"></i>SystemJS + Single SPA (Port 4005)</small>
        </div>
      </div>
    </div>
  `;
  
  return Promise.resolve();
}

// Single SPA lifecycle: unmount
function unmount(props) {
  console.log('Job Descriptions Widget: Unmount called');
  
  if (mountedContainer) {
    mountedContainer.innerHTML = '';
    mountedContainer = null;
  }
  
  return Promise.resolve();
}

// SystemJS module registration for Single SPA
if (typeof System !== 'undefined') {
  System.register([], function() {
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
  window.jobDescriptionsWidget = { bootstrap, mount, unmount };
}