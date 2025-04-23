
# BudDrop - Cannabis Delivery Platform

A full-stack application for cannabis delivery, with SwiftUI iOS client and Flask backend.

## Project Structure

```
.
├── server/             # Flask backend
│   ├── app/            # Application package
│   │   ├── api/        # API endpoints
│   │   ├── models.py   # Database models
│   │   └── __init__.py # Application factory
│   ├── config.py       # Configuration
│   ├── run.py          # Application entrypoint
│   ├── requirements.txt # Python dependencies
│   └── Procfile        # Heroku deployment config
└── ios/                # iOS SwiftUI app
    └── BudDrop/        # SwiftUI project
        ├── App/        # App entrypoint
        ├── Models/     # Data models
        ├── Views/      # SwiftUI views
        ├── Networking/ # API client and networking
        ├── Services/   # Business logic and state management
        └── Resources/  # Assets and localization
```

## Backend Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd buddrop/server

# Create a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
cp .env.sample .env
# Edit .env with your settings

# Run the server
python run.py
```

## iOS App Setup

1. Open the project in Xcode:
```bash
cd ios/BudDrop
open BudDrop.xcodeproj
```

2. Install dependencies with Swift Package Manager:
- Stripe iOS SDK
- Starscream (WebSocket client)

3. Configure backend URL in APIClient.swift:
- For local development: `http://localhost:5000/api`
- For production: `https://your-app.herokuapp.com/api`

4. Build and run on simulator or device

## Heroku Deployment

1. Create a Heroku app:
```bash
heroku create buddrop-app
```

2. Add PostgreSQL add-on:
```bash
heroku addons:create heroku-postgresql:hobby-dev
```

3. Configure environment variables:
```bash
heroku config:set SECRET_KEY=your_secret_key
heroku config:set JWT_SECRET_KEY=your_jwt_secret_key
heroku config:set APP_SETTINGS=config.ProductionConfig
heroku config:set STRIPE_SECRET_KEY=your_stripe_secret_key
heroku config:set STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
heroku config:set STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
```

4. Deploy:
```bash
git subtree push --prefix server heroku main
```

## Security Considerations

- JWT secrets should be strong, random strings
- Stripe keys must be kept secure
- User passwords are hashed using Werkzeug's secure functions
- Frontend stores JWT token in secure storage
- API endpoints are protected with role-based authorization

## Future Enhancements

- Driver role integration
- Geolocation tracking for orders
- Push notifications
- User profiles and preferences
- Order history and analytics
- Loyalty program
- Tipping feature

## API Documentation

The API documentation is available in Postman. Import the collection from:
[BudDrop API Collection](link-to-your-postman-collection)
