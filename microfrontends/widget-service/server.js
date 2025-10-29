const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 4005;

app.use(cors());
app.use(express.static(path.join(__dirname, 'src')));

// Serve the Single SPA microfrontend with proper JSX transpilation
app.get('/job-descriptions-microfrontend.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  
  try {
    // Try to load Babel for JSX transpilation
    let babel;
    try {
      babel = require('@babel/core');
    } catch (e) {
      return serveFallback(res);
    }

    // Read the JSX file
    const jsxFilePath = path.join(__dirname, 'src', 'job-descriptions-microfrontend.jsx');
    
    if (!fs.existsSync(jsxFilePath)) {
      return serveFallback(res);
    }
    
    const jsxContent = fs.readFileSync(jsxFilePath, 'utf8');
    
    // Transpile JSX to JavaScript
    const result = babel.transformSync(jsxContent, {
      presets: [
        ['@babel/preset-react', { 
          runtime: 'classic',
          pragma: 'React.createElement'
        }]
      ],
      filename: 'job-descriptions-microfrontend.jsx'
    });
    
    // Wrap with React availability check and SystemJS registration
    const wrappedMicrofrontend = `
// Ensure React and ReactDOM are available
if (typeof React === 'undefined') {
  console.error('❌ React is not available! Make sure React is loaded before this microfrontend.');
  throw new Error('React is required but not available globally');
}

if (typeof ReactDOM === 'undefined') {
  console.error('❌ ReactDOM is not available! Make sure ReactDOM is loaded before this microfrontend.');
  throw new Error('ReactDOM is required but not available globally');
}

console.log('✅ React and ReactDOM are available, loading microfrontend...');

${result.code}

// SystemJS module registration for Single SPA
System.register([], function() {
  'use strict';
  
  return {
    execute: function() {
      // Export lifecycle functions as default export
      this.default = { bootstrap, mount, unmount };
      console.log('✅ Job Descriptions Microfrontend registered with SystemJS');
    }
  };
});
`;

    res.send(wrappedMicrofrontend);
    
  } catch (error) {
    serveFallback(res);
  }
});

// Fallback function for when JSX transpilation fails
function serveFallback(res) {
  const fallbackMicrofrontend = `
console.log('⚠️ Serving fallback microfrontend...');

let mountedContainer = null;

function bootstrap(props) {
  console.log('📦 Bootstrap Job Descriptions Microfrontend (Fallback)', props);
  return Promise.resolve();
}

function mount(props) {
  console.log('🔧 Mount Job Descriptions Microfrontend (Fallback)', props);
  
  const container = props.domElement;
  if (!container) {
    return Promise.reject(new Error('No domElement provided'));
  }

  mountedContainer = container;
  const { jobDescriptions = [], user = {} } = props;

  container.innerHTML = \`
    <div class="alert alert-warning">
      <h4>Job Descriptions Microfrontend (Fallback)</h4>
      <p>User: \${user.email || 'Unknown'} | Jobs: \${jobDescriptions.length}</p>
      <p><strong>Note:</strong> JSX transpilation failed. Using fallback.</p>
    </div>
  \`;

  return Promise.resolve();
}

function unmount(props) {
  console.log('🗑️ Unmount Job Descriptions Microfrontend (Fallback)');
  
  if (mountedContainer) {
    mountedContainer.innerHTML = '';
    mountedContainer = null;
  }
  
  return Promise.resolve();
}

window.jobDescriptionsMicrofrontend = {
  bootstrap,
  mount,
  unmount
};

System.register([], function() {
  'use strict';
  
  return {
    execute: function() {
      // Export lifecycle functions as default export
      this.default = { bootstrap, mount, unmount };
    }
  };
});
`;
  
  res.send(fallbackMicrofrontend);
}

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'job-descriptions-microfrontend',
    endpoints: ['/job-descriptions-microfrontend.js']
  });
});

// Root endpoint  
app.get('/', (req, res) => {
  res.json({
    name: 'Job Descriptions Microfrontend Service',
    endpoints: {
      'job-descriptions': '/job-descriptions-microfrontend.js'
    },
    features: ['Single SPA', 'SystemJS', 'React JSX', 'Babel Transpilation']
  });
});

app.listen(PORT, () => {
  console.log(`Dashboard Widget Service running on port ${PORT}`);
});