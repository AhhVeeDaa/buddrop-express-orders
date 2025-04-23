
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import db, socketio
from app.models import Order, User
import stripe
import time

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('', methods=['POST'])
@jwt_required()
def create_order():
    # Get current user from JWT
    current_user = get_jwt_identity()
    
    # Verify user is a customer
    if current_user['role'] != 'customer':
        return jsonify({'message': 'Only customers can place orders'}), 403
    
    # Get order data from request
    data = request.get_json()
    if not all(k in data for k in ('product_name', 'price', 'business_id')):
        return jsonify({'message': 'Missing required fields'}), 400
    
    # Create Stripe Payment Intent
    stripe.api_key = current_app.config['STRIPE_SECRET_KEY']
    amount = int(data['price'] * 100)  # Convert to cents
    
    try:
        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency='usd',
            metadata={
                'customer_id': current_user['user_id'],
                'business_id': data['business_id'],
                'product_name': data['product_name']
            }
        )
    except stripe.error.StripeError as e:
        return jsonify({'message': f'Stripe error: {str(e)}'}), 400
    
    # Create order
    order = Order(
        product_name=data['product_name'],
        price=data['price'],
        business_id=data['business_id'],
        customer_id=current_user['user_id'],
        payment_intent_id=intent.id,
        payment_status='pending'
    )
    
    db.session.add(order)
    db.session.commit()
    
    # Emit socket event to notify business
    socketio.emit(
        'new_order',
        {'order': order.to_dict()},
        room=f"business_{data['business_id']}"
    )
    
    return jsonify({
        'message': 'Order created successfully',
        'order': order.to_dict(),
        'client_secret': intent.client_secret
    }), 201

@orders_bp.route('', methods=['GET'])
@jwt_required()
def get_orders():
    current_user = get_jwt_identity()
    
    if current_user['role'] == 'customer':
        # Get orders placed by this customer
        orders = Order.query.filter_by(customer_id=current_user['user_id']).all()
    elif current_user['role'] == 'business':
        # Get orders for this business
        if not current_user.get('business_id'):
            return jsonify({'message': 'Missing business ID'}), 400
        
        orders = Order.query.filter_by(business_id=current_user['business_id']).all()
    else:
        return jsonify({'message': 'Invalid user role'}), 403
    
    return jsonify({
        'orders': [order.to_dict() for order in orders]
    }), 200

@orders_bp.route('/<int:order_id>/status', methods=['PUT'])
@jwt_required()
def update_order_status(order_id):
    current_user = get_jwt_identity()
    
    # Only businesses can update order status
    if current_user['role'] != 'business':
        return jsonify({'message': 'Only businesses can update order status'}), 403
    
    order = Order.query.get(order_id)
    if not order:
        return jsonify({'message': 'Order not found'}), 404
    
    # Verify business owns this order
    if order.business_id != current_user['business_id']:
        return jsonify({'message': 'Unauthorized to update this order'}), 403
    
    # Update order status
    data = request.get_json()
    if 'status' not in data:
        return jsonify({'message': 'Missing status field'}), 400
    
    valid_statuses = ['pending', 'confirmed', 'in_delivery', 'delivered']
    if data['status'] not in valid_statuses:
        return jsonify({'message': f'Invalid status. Must be one of {valid_statuses}'}), 400
    
    order.status = data['status']
    db.session.commit()
    
    # Emit socket event to notify customer
    socketio.emit(
        'order_status_updated',
        {'order': order.to_dict()},
        room=f"user_{order.customer_id}"
    )
    
    return jsonify({
        'message': 'Order status updated',
        'order': order.to_dict()
    }), 200

@orders_bp.route('/webhook', methods=['POST'])
def stripe_webhook():
    # Get webhook secret from config
    webhook_secret = current_app.config.get('STRIPE_WEBHOOK_SECRET')
    
    # Get webhook data
    payload = request.get_data()
    sig_header = request.headers.get('Stripe-Signature')
    
    # Verify webhook signature and get event
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except ValueError as e:
        return jsonify({'message': 'Invalid payload'}), 400
    except stripe.error.SignatureVerificationError as e:
        return jsonify({'message': 'Invalid signature'}), 400
    
    # Handle specific webhook events
    if event['type'] == 'payment_intent.succeeded':
        payment_intent = event['data']['object']
        handle_payment_success(payment_intent)
    elif event['type'] == 'payment_intent.payment_failed':
        payment_intent = event['data']['object']
        handle_payment_failure(payment_intent)
    
    return jsonify({'status': 'success'}), 200

def handle_payment_success(payment_intent):
    # Find order by payment intent ID
    order = Order.query.filter_by(payment_intent_id=payment_intent['id']).first()
    if not order:
        current_app.logger.error(f"Order not found for payment: {payment_intent['id']}")
        return
    
    order.payment_status = 'succeeded'
    db.session.commit()
    
    # Notify business of successful payment
    socketio.emit(
        'payment_succeeded',
        {'order': order.to_dict()},
        room=f"business_{order.business_id}"
    )

def handle_payment_failure(payment_intent):
    # Find order by payment intent ID
    order = Order.query.filter_by(payment_intent_id=payment_intent['id']).first()
    if not order:
        current_app.logger.error(f"Order not found for payment: {payment_intent['id']}")
        return
    
    order.payment_status = 'failed'
    db.session.commit()
