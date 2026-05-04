# EV Ride App - Production Deployment Guide

## 1. Environment Variables (.env)
Create a `.env` file in the `backend/` directory with the following variables for production:

```env
NODE_ENV=production
PORT=5000
MONGO_URI=your_production_mongodb_atlas_connection_string
JWT_SECRET=your_super_strong_random_secret
JWT_EXPIRES_IN=30d
SMTP_HOST=smtp.mailtrap.io
SMTP_PORT=587
SMTP_USER=your_user
SMTP_PASS=your_pass
GOOGLE_CLIENT_ID=your_google_client_id
```

## 2. Deployment Steps
1.  **Dockerize:** Use the provided `Dockerfile` to build your backend image.
    ```bash
    docker build -t ev-ride-backend .
    ```
2.  **Deploy:** Push this image to your preferred container registry (e.g., Docker Hub) and deploy to a platform like Render, Railway, or AWS ECS.
3.  **Frontend:** For Flutter Web, run `flutter build web --release` and serve the `build/web` folder using an Nginx or Firebase Hosting container.

## 3. Testing Status
- **Backend:** Unit tests have been structured using Jest.
- **Frontend:** Flutter widget tests are initialized. 
- **System:** The app flow (Booking -> Driver -> Payment -> Rating) is validated.
