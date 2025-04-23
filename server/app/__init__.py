
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_socketio import SocketIO
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize extensions
db = SQLAlchemy()
jwt = JWTManager()
socketio = SocketIO()

def create_app(config_name=None):
    app = Flask(__name__)
    
    # Configure app
    app_settings = os.getenv('APP_SETTINGS', 'config.DevelopmentConfig')
    app.config.from_object(app_settings)
    
    # Initialize extensions with app
    db.init_app(app)
    jwt.init_app(app)
    CORS(app)
    socketio.init_app(app, cors_allowed_origins="*")
    
    # Import and register blueprints
    from app.api.auth import auth_bp
    from app.api.orders import orders_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(orders_bp, url_prefix='/api/orders')
    
    # Create database tables
    with app.app_context():
        db.create_all()
    
    return app
