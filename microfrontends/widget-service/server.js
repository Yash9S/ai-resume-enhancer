const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4005;

app.use(cors());
app.use(express.static(path.join(__dirname, 'src')));

// Serve the Single SPA microfrontend with proper JSX transpilation
app.get('/job-descriptions-microfrontend.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  
  const fs = require('fs');
  const path = require('path');
  const babel = require('@babel/core');
  
  try {
    const jsxContent = fs.readFileSync(path.join(__dirname, 'src', 'job-descriptions-microfrontend.jsx'), 'utf8');
    
    // Transpile JSX to JavaScript using Babel
    const result = babel.transformSync(jsxContent, {
      presets: ['@babel/preset-react'],
      filename: 'job-descriptions-microfrontend.jsx'
    });
    
    res.send(result.code);
  } catch (error) {
    console.error('Error transpiling JSX:', error);
    res.status(500).send('Error loading microfrontend');
  }
});

// Serve the original dashboard widget (for backward compatibility)
app.get('/dashboard-widget.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.sendFile(path.join(__dirname, 'src', 'dashboard-widget.js'));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'job-descriptions-microfrontend',
    endpoints: ['/job-descriptions-microfrontend.js', '/dashboard-widget.js']
  });
});

// Root endpoint  
app.get('/', (req, res) => {
  res.json({
    name: 'Job Descriptions Microfrontend Service',
    endpoints: {
      'job-descriptions': '/job-descriptions-microfrontend.js',
      'dashboard-widget': '/dashboard-widget.js'
    },
    features: ['Single SPA', 'SystemJS ImportMap', 'React Components', 'JSX Transpilation']
  });
});

app.listen(PORT, () => {
  console.log(`Dashboard Widget Service running on port ${PORT}`);
});