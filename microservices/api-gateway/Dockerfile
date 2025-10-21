FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf

# Create directory for static files
RUN mkdir -p /app/public/uploads

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]