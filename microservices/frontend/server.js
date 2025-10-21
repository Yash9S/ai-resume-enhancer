const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>AI Resume Parser - Microservices</title></head>
      <body>
        <h1>🚀 AI Resume Parser Frontend</h1>
        <p>Frontend service is running!</p>
        <p>This is a placeholder. You can integrate with your existing React components.</p>
        <ul>
          <li>Business API: <a href="http://localhost:3001/health">http://localhost:3001</a></li>
          <li>AI Service: <a href="http://localhost:8001/health">http://localhost:8001</a></li>
          <li>API Gateway: <a href="http://localhost:8080/health">http://localhost:8080</a></li>
        </ul>
      </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'frontend', timestamp: new Date().toISOString() });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend service running on http://localhost:${port}`);
});