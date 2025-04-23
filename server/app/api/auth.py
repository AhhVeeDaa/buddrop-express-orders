
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from app import db
from app.models import User

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    # Validate request data
    if not all(k in data for k in ('username', 'password', 'role')):
        return jsonify({'message': 'Missing required fields'}), 400
    
    # Check if username already exists
    if User.query.filter_by(username=data['username']).first():
        return jsonify({'message': 'Username already exists'}), 409
    
    # Create new user
    user = User(
        username=data['username'],
        role=data['role']
    )
    user.set_password(data['password'])
    
    # Add business details if applicable
    if data['role'] == 'business':
        if not all(k in data for k in ('business_id', 'business_name')):
            return jsonify({'message': 'Missing business details'}), 400
        user.business_id = data['business_id']
        user.business_name = data['business_name']
    
    db.session.add(user)
    db.session.commit()
    
    return jsonify({'message': 'User created successfully'}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    # Validate request data
    if not all(k in data for k in ('username', 'password')):
        return jsonify({'message': 'Missing required fields'}), 400
    
    # Find user
    user = User.query.filter_by(username=data['username']).first()
    if not user or not user.check_password(data['password']):
        return jsonify({'message': 'Invalid credentials'}), 401
    
    # Create access token
    access_token = create_access_token(
        identity={
            'user_id': user.id,
            'role': user.role,
            'business_id': user.business_id
        }
    )
    
    return jsonify({
        'access_token': access_token,
        'user': user.to_dict()
    }), 200

@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    current_user_id = get_jwt_identity()['user_id']
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
    
    return jsonify(user.to_dict()), 200
