# Microfrontends Architecture

This folder contains the microfrontend services for the AI Resume Parser application, implementing a modern Single SPA + SystemJS architecture for modular, scalable frontend development.

## 🏗️ Architecture Overview

### Technology Stack
- **Single SPA 5.9.3**: Microfrontend orchestration framework
- **SystemJS 6.14.1**: Dynamic module loading system
- **React 18**: Frontend library loaded globally via CDN
- **Babel Core 7.28.5**: JSX transpilation in Express.js servers
- **Express.js**: Microfrontend serving infrastructure
- **Docker**: Container orchestration for services

### Key Components
```
microfrontends/
├── widget-service/           # Job Descriptions Microfrontend
│   ├── server.js            # Express server with Babel transpilation
│   ├── src/
│   │   └── job-descriptions-microfrontend.jsx  # Main React component
│   ├── package.json         # Node.js dependencies
│   └── Dockerfile          # Container configuration
├── docker-compose.yml       # Service orchestration
└── README.md               # This file
```

## 🚀 How Microfrontends Work

### 1. Bootstrap Process

**Step 1: Global Dependencies Loading**
```html
<!-- In app/views/layouts/application.html.erb -->
<script src="https://unpkg.com/react@18/umd/react.development.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
<script src="https://cdn.jsdelivr.net/npm/systemjs@6.14.1/dist/system.min.js"></script>
```

**Step 2: SystemJS ImportMap Configuration**
```javascript
{
  "imports": {
    "single-spa": "https://cdn.jsdelivr.net/npm/single-spa@5.9.3/lib/system/single-spa.min.js",
    "job-descriptions-microfrontend": "http://localhost:4005/job-descriptions-microfrontend.js"
  }
}
```

**Step 3: React Availability Check**
The microfrontend waits for React to be fully loaded before proceeding:
```javascript
function waitForReact() {
  return new Promise((resolve, reject) => {
    function checkReact() {
      if (typeof React !== 'undefined' && typeof ReactDOM !== 'undefined') {
        resolve();
      } else {
        setTimeout(checkReact, 100);
      }
    }
    checkReact();
  });
}
```

### 2. Microfrontend Server Architecture

**Express.js Server with Babel Transpilation:**
```javascript
// microfrontends/widget-service/server.js
app.get('/job-descriptions-microfrontend.js', (req, res) => {
  // Read JSX file
  const jsxContent = fs.readFileSync('job-descriptions-microfrontend.jsx', 'utf8');
  
  // Transpile JSX to JavaScript
  const result = babel.transformSync(jsxContent, {
    presets: [['@babel/preset-react', { 
      runtime: 'classic',
      pragma: 'React.createElement'
    }]]
  });
  
  // Wrap with React availability check and SystemJS registration
  const wrappedMicrofrontend = `
    if (typeof React === 'undefined') {
      throw new Error('React is required but not available globally');
    }
    
    ${result.code}
    
    // SystemJS module registration
    System.register([], function() {
      return {
        execute: function() {
          this.bootstrap = bootstrap;
          this.mount = mount;
          this.unmount = unmount;
        }
      };
    });
  `;
  
  res.send(wrappedMicrofrontend);
});
```

### 3. Single SPA Lifecycle Functions

**Bootstrap Function:**
```javascript
function bootstrap(props) {
  console.log('📦 Bootstrap Job Descriptions Microfrontend', props);
  // Initialize any global state or configuration
  return Promise.resolve();
}
```

**Mount Function:**
```javascript
function mount(props) {
  console.log('🔧 Mount Job Descriptions Microfrontend', props);
  
  const container = props.domElement;
  const { jobDescriptions = [], user = {} } = props;

  // Create React root and render the component
  mountedRoot = createRoot(container);
  mountedRoot.render(
    <JobDescriptionsMicrofrontend
      jobDescriptions={jobDescriptions}
      user={user}
    />
  );

  return Promise.resolve();
}
```

**Unmount Function:**
```javascript
function unmount(props) {
  console.log('🗑️ Unmount Job Descriptions Microfrontend');
  
  if (mountedRoot) {
    mountedRoot.unmount();
    mountedRoot = null;
  }
  
  return Promise.resolve();
}
```

### 4. Integration with Rails Application

**Rails View Integration:**
```erb
<!-- app/views/job_descriptions/index.html.erb -->
<div id="job-descriptions-microfrontend" 
     data-job-descriptions='<%= @job_descriptions.to_json.html_safe %>'
     data-user='<%= current_user.to_json.html_safe %>'>
  <!-- Loading state -->
</div>

<script>
  // Wait for React, then load microfrontend
  waitForReact()
    .then(() => System.import('job-descriptions-microfrontend'))
    .then((microfrontend) => {
      // Register with Single SPA
      registerApplication({
        name: 'job-descriptions-app',
        app: () => Promise.resolve({
          bootstrap: window.jobDescriptionsMicrofrontend.bootstrap,
          mount: window.jobDescriptionsMicrofrontend.mount,
          unmount: window.jobDescriptionsMicrofrontend.unmount
        }),
        activeWhen: () => true,
        customProps: {
          domElement: container,
          jobDescriptions: jobDescriptions,
          user: user
        }
      });
      
      start(); // Start Single SPA
    });
</script>
```

## 🔄 Data Flow

### 1. Server-Side Data Preparation
```ruby
# app/controllers/job_descriptions_controller.rb
def index
  @job_descriptions = current_tenant.job_descriptions.includes(:user)
  # Data is serialized in the ERB template
end
```

### 2. Data Transfer to Microfrontend
```erb
<!-- Data attributes in HTML -->
<div data-job-descriptions='<%= @job_descriptions.to_json.html_safe %>'
     data-user='<%= current_user.to_json.html_safe %>'>
```

### 3. Microfrontend Data Consumption
```javascript
// Extracted in JavaScript
const jobDescriptionsData = container.dataset.jobDescriptions;
const userData = container.dataset.user;

const jobDescriptions = JSON.parse(jobDescriptionsData);
const user = JSON.parse(userData);
```

### 4. React Component State Management
```jsx
const JobDescriptionsMicrofrontend = ({ jobDescriptions = [], user = {} }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredJobs, setFilteredJobs] = useState(jobDescriptions);

  useEffect(() => {
    const filtered = jobDescriptions.filter(job =>
      job.title.toLowerCase().includes(searchTerm.toLowerCase())
    );
    setFilteredJobs(filtered);
  }, [searchTerm, jobDescriptions]);
  
  // Component rendering...
};
```

## 🐳 Docker Infrastructure

### Service Configuration
```yaml
# docker-compose.yml
services:
  dashboard-widget-service:
    build: ./microfrontends/widget-service
    ports:
      - "4005:4005"
    environment:
      - NODE_ENV=development
    volumes:
      - ./microfrontends/widget-service:/app
      - /app/node_modules
```

### Dockerfile
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4005
CMD ["node", "server.js"]
```

## 🚦 Loading Sequence

1. **Page Load**: Rails renders the job descriptions index page
2. **React Loading**: CDN scripts load React and ReactDOM globally
3. **SystemJS Setup**: ImportMap configures module locations
4. **DOM Ready**: JavaScript waits for DOM and React availability
5. **Microfrontend Import**: SystemJS loads the transpiled microfrontend
6. **Single SPA Registration**: Microfrontend is registered with lifecycle functions
7. **Bootstrap**: Initialize microfrontend (setup phase)
8. **Mount**: Render React component in DOM container with data
9. **User Interaction**: React handles UI interactions and state changes
10. **Unmount**: Clean up when navigating away (if needed)

## 🔧 Development Workflow

### Starting Services
```bash
# Start all services
docker-compose up

# Start specific microfrontend
docker-compose up dashboard-widget-service

# Rebuild after changes
docker-compose up --build dashboard-widget-service
```

### Adding New Microfrontends

1. **Create Service Directory**
   ```bash
   mkdir microfrontends/new-service
   cd microfrontends/new-service
   ```

2. **Create Express Server**
   ```javascript
   // server.js - follow widget-service pattern
   // - Babel transpilation
   // - React availability checks
   // - SystemJS registration
   ```

3. **Create React Component**
   ```jsx
   // src/new-microfrontend.jsx
   // - Single SPA lifecycle functions
   // - Modern JSX syntax
   // - Global window export
   ```

4. **Add to SystemJS ImportMap**
   ```html
   <!-- In application.html.erb -->
   "new-microfrontend": "http://localhost:XXXX/new-microfrontend.js"
   ```

5. **Integrate in Rails Views**
   ```erb
   <!-- Follow job_descriptions/index.html.erb pattern -->
   <!-- - Data attributes
   <!-- - Loading states
   <!-- - Fallback UI
   ```

## 🛡️ Error Handling

### Fallback Mechanisms
- **React Unavailable**: Show error message and load fallback UI
- **Microfrontend Timeout**: Automatically show Rails fallback after 15 seconds
- **SystemJS Import Failure**: Catch errors and display traditional Rails view
- **Babel Transpilation Error**: Serve minimal fallback microfrontend

### Debugging
```javascript
// Console logging throughout the flow
console.log('🔄 Starting microfrontend...');
console.log('✅ React available');
console.log('📦 Microfrontend loaded');
console.log('🚀 Single SPA started');
```

## 📝 Best Practices

### JSX Development
- Always use modern JSX syntax: `<div className="...">` instead of `React.createElement`
- Ensure React is available globally before accessing it
- Use proper error boundaries in components

### SystemJS Integration
- Export lifecycle functions to `window` object for reliable access
- Use consistent naming conventions across microfrontends
- Always provide fallback mechanisms

### Performance
- Load React once globally rather than bundling with each microfrontend
- Use CDN for stable dependencies (React, SystemJS, Single SPA)
- Implement proper cleanup in unmount functions

### Security
- Validate all data passed to microfrontends
- Use CORS properly for cross-origin requests
- Sanitize user input in React components

## 🔍 Troubleshooting

### Common Issues

**"React is not defined"**
- Ensure React CDN scripts load before microfrontend
- Check browser network tab for failed script loads
- Verify React availability with `waitForReact()` function

**"Microfrontend Unavailable"**
- Check Docker container is running: `docker-compose ps`
- Verify port 4005 is accessible: `curl http://localhost:4005/health`
- Check SystemJS ImportMap URL configuration

**"Lifecycle functions not found"**
- Verify `window.jobDescriptionsMicrofrontend` exists
- Check Babel transpilation is working
- Ensure SystemJS registration is complete

**Empty microfrontend container**
- Check database has job descriptions data
- Verify data attributes are properly serialized
- Confirm JSON parsing is successful

This architecture provides a robust, scalable foundation for microfrontend development in the AI Resume Parser application, enabling independent development and deployment of frontend features while maintaining seamless integration with the Rails backend.