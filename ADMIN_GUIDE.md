# Multi-Tenant Admin Guide

## Overview
The AI Resume Parser now supports multi-tenancy with comprehensive analytics through a global admin dashboard.

## Admin Dashboard Access
- **URL**: `all.yourdomain.com` (or `all.localhost:3000` for development)
- **Access**: Admin users only
- **Purpose**: Analytics and tenant management across all clients

## Analytics Features

### Global Analytics Dashboard
The admin dashboard provides comprehensive analytics:

1. **Total Subdomains**: Number of active client tenants
2. **Total Resumes**: All resumes uploaded across all clients
3. **Total Job Descriptions**: All JDs created by all clients
4. **Total Processings**: All processing attempts across the platform

### Processing Analytics
- **Successful Processings**: Count and success rate
- **Failed Processings**: Count and failure rate  
- **Currently Processing**: Real-time processing status

### Global Overview Metrics
- Average resumes per client
- Average job descriptions per client
- Total users across all tenants

## Tenant Management

### Creating New Tenants
1. Access admin dashboard at `all.yourdomain.com`
2. Click "Manage Tenants"
3. Click "New Tenant"
4. Fill in:
   - **Organization Name**: Display name
   - **Subdomain**: URL subdomain (e.g., 'acme' for acme.yourdomain.com)
   - **Schema Name**: Database schema (auto-generated if empty)
   - **Status**: Active/Inactive/Pending

### Tenant Features
- **Isolated Data**: Each tenant has separate database schema
- **Custom Subdomains**: `{tenant}.yourdomain.com`
- **User Management**: Per-tenant user accounts
- **Resume Processing**: Isolated processing per tenant

## Usage Instructions

### For Admins (all.yourdomain.com)
1. Monitor global analytics
2. Create new tenants
3. Manage tenant status
4. View system health via Sidekiq

### For Clients ({tenant}.yourdomain.com)
1. Upload resumes
2. Create job descriptions  
3. Process resume-job matches
4. View tenant-specific analytics

## Technical Details

### Database Structure
- **Public Schema**: Users, Tenants, global admin data
- **Tenant Schemas**: Resumes, JobDescriptions, ResumeProcessings per tenant

### Security Features
- Tenant isolation via database schemas
- Admin-only access to global dashboard
- Subdomain-based routing and access control

## Development Setup

### Local Development URLs
- Admin Dashboard: `http://all.localhost:3000`
- Tenant Example: `http://acme.localhost:3000`

### Production URLs  
- Admin Dashboard: `https://all.yourdomain.com`
- Tenant Example: `https://acme.yourdomain.com`

## Next Steps
The system is ready for:
1. Creating new tenants
2. Client onboarding
3. Analytics monitoring
4. Scaling across multiple clients

This analytics-focused admin dashboard provides comprehensive insights without exposing operational functionalities to maintain security and clarity.