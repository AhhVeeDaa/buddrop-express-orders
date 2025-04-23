
from flask_socketio import emit, join_room, leave_room
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from app import socketio
from functools import wraps

def jwt_required_for_socketio(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        try:
            verify_jwt_in_request()
        except Exception as e:
            emit('error', {'message': 'Authentication failed'})
            return
        return f(*args, **kwargs)
    return decorated

@socketio.on('connect')
def handle_connect():
    pass

@socketio.on('disconnect')
def handle_disconnect():
    pass

@socketio.on('join')
@jwt_required_for_socketio
def handle_join(data):
    current_user = get_jwt_identity()
    
    # Join room based on user role
    if current_user['role'] == 'customer':
        room = f"user_{current_user['user_id']}"
        join_room(room)
        emit('status', {'message': f'Joined customer room: {room}'})
    elif current_user['role'] == 'business':
        room = f"business_{current_user['business_id']}"
        join_room(room)
        emit('status', {'message': f'Joined business room: {room}'})
