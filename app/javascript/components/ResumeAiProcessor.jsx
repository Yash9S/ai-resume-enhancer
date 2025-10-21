import React, { useState, useEffect } from 'react'
import PropTypes from 'prop-types'

const ResumeAiProcessor = ({ resumeId, availableProviders, jobDescriptions }) => {
  const [processing, setProcessing] = useState(false)
  const [provider, setProvider] = useState('ollama')
  const [jobDescriptionId, setJobDescriptionId] = useState('')
  const [status, setStatus] = useState(null)
  const [error, setError] = useState(null)
  const [result, setResult] = useState(null)

  useEffect(() => {
    // Check if there's ongoing processing for this resume
    checkProcessingStatus()
  }, [resumeId])

  const checkProcessingStatus = async () => {
    try {
      const response = await fetch(`/resumes/${resumeId}/ai_status`)
      if (response.ok) {
        const data = await response.json()
        setStatus(data.processing_status)
        if (data.processing_status === 'completed' && data.ai_data) {
          setResult(data.ai_data)
        }
        if (data.processing_status === 'failed') {
          setError(data.processing_error)
        }
      }
    } catch (err) {
      console.error('Failed to check processing status:', err)
    }
  }

  const startAiProcessing = async () => {
    setProcessing(true)
    setError(null)
    setResult(null)

    try {
      const response = await fetch(`/resumes/${resumeId}/process_ai`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          ai_provider: provider,
          job_description_id: jobDescriptionId || null
        })
      })

      if (response.ok) {
        const data = await response.json()
        setStatus('queued')
        
        // Poll for updates
        pollForUpdates()
        
        // Show success toast
        if (typeof toastr !== 'undefined') {
          toastr.success('AI processing started! We\'ll update you when it\'s complete.')
        }
      } else {
        const errorData = await response.json()
        setError(errorData.error || 'Failed to start AI processing')
      }
    } catch (err) {
      setError('Network error occurred')
      console.error('AI processing error:', err)
    } finally {
      setProcessing(false)
    }
  }

  const pollForUpdates = () => {
    const interval = setInterval(async () => {
      await checkProcessingStatus()
      
      // Stop polling if processing is complete or failed
      if (status === 'completed' || status === 'failed') {
        clearInterval(interval)
      }
    }, 3000) // Poll every 3 seconds

    // Clean up after 5 minutes
    setTimeout(() => clearInterval(interval), 300000)
  }

  const renderProcessingStatus = () => {
    switch (status) {
      case 'pending':
        return <span className="badge bg-secondary">Pending</span>
      case 'queued':
        return <span className="badge bg-info">Queued</span>
      case 'processing':
        return (
          <span className="badge bg-warning">
            <span className="spinner-border spinner-border-sm me-1" role="status"></span>
            Processing...
          </span>
        )
      case 'completed':
        return <span className="badge bg-success">Completed</span>
      case 'failed':
        return <span className="badge bg-danger">Failed</span>
      default:
        return <span className="badge bg-light">Not Processed</span>
    }
  }

  const renderExtractedData = () => {
    if (!result) return null

    return (
      <div className="card mt-3">
        <div className="card-header">
          <h5>AI Extracted Information</h5>
        </div>
        <div className="card-body">
          <div className="row">
            {result.name && (
              <div className="col-md-6 mb-2">
                <strong>Name:</strong> {result.name}
              </div>
            )}
            {result.email && (
              <div className="col-md-6 mb-2">
                <strong>Email:</strong> {result.email}
              </div>
            )}
            {result.phone && (
              <div className="col-md-6 mb-2">
                <strong>Phone:</strong> {result.phone}
              </div>
            )}
            {result.location && (
              <div className="col-md-6 mb-2">
                <strong>Location:</strong> {result.location}
              </div>
            )}
          </div>
          
          {result.summary && (
            <div className="mt-3">
              <strong>Summary:</strong>
              <p className="mt-1">{result.summary}</p>
            </div>
          )}
          
          {result.skills && result.skills.length > 0 && (
            <div className="mt-3">
              <strong>Skills:</strong>
              <div className="mt-1">
                {result.skills.map((skill, index) => (
                  <span key={index} className="badge bg-primary me-1 mb-1">
                    {skill}
                  </span>
                ))}
              </div>
            </div>
          )}
          
          {result.match_score && (
            <div className="mt-3">
              <strong>Job Match Score:</strong>
              <div className="progress mt-1">
                <div 
                  className="progress-bar" 
                  style={{ width: `${result.match_score}%` }}
                >
                  {result.match_score}%
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="ai-processor-component">
      <div className="card">
        <div className="card-body">
          <div className="d-flex justify-content-between align-items-center mb-3">
            <h5 className="card-title mb-0">AI Processing</h5>
            {renderProcessingStatus()}
          </div>

          {error && (
            <div className="alert alert-danger">
              <strong>Error:</strong> {error}
            </div>
          )}

          {(status === 'pending' || status === 'failed' || !status) && (
            <div className="row g-3">
              <div className="col-md-6">
                <label className="form-label">AI Provider</label>
                <select 
                  className="form-select" 
                  value={provider}
                  onChange={(e) => setProvider(e.target.value)}
                  disabled={processing}
                >
                  {availableProviders.map(p => (
                    <option key={p.name} value={p.name}>
                      {p.display_name} {p.cost === 'free' ? '(Free)' : `($${p.cost})`}
                    </option>
                  ))}
                </select>
              </div>

              <div className="col-md-6">
                <label className="form-label">Job Description (Optional)</label>
                <select 
                  className="form-select" 
                  value={jobDescriptionId}
                  onChange={(e) => setJobDescriptionId(e.target.value)}
                  disabled={processing}
                >
                  <option value="">Select job description...</option>
                  {jobDescriptions.map(jd => (
                    <option key={jd.id} value={jd.id}>
                      {jd.title}
                    </option>
                  ))}
                </select>
                <div className="form-text">
                  Select a job description to get tailored resume enhancements
                </div>
              </div>

              <div className="col-12">
                <button 
                  className="btn btn-primary"
                  onClick={startAiProcessing}
                  disabled={processing}
                >
                  {processing ? (
                    <>
                      <span className="spinner-border spinner-border-sm me-2" role="status"></span>
                      Starting...
                    </>
                  ) : (
                    'Process with AI'
                  )}
                </button>
              </div>
            </div>
          )}

          {renderExtractedData()}
        </div>
      </div>
    </div>
  )
}

ResumeAiProcessor.propTypes = {
  resumeId: PropTypes.number.isRequired,
  availableProviders: PropTypes.arrayOf(PropTypes.shape({
    name: PropTypes.string.isRequired,
    display_name: PropTypes.string.isRequired,
    cost: PropTypes.string.isRequired
  })).isRequired,
  jobDescriptions: PropTypes.arrayOf(PropTypes.shape({
    id: PropTypes.number.isRequired,
    title: PropTypes.string.isRequired
  })).isRequired
}

ResumeAiProcessor.defaultProps = {
  availableProviders: [
    { name: 'ollama', display_name: 'Ollama (Local AI)', cost: 'free' },
    { name: 'basic', display_name: 'Basic Parser (Fallback)', cost: 'free' }
  ],
  jobDescriptions: []
}

export default ResumeAiProcessor