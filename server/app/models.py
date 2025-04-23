
from app import db
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # 'customer' or 'business'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # For business users
    business_id = db.Column(db.String(50), nullable=True)
    business_name = db.Column(db.String(120), nullable=True)
    
    # Relationships
    orders_placed = db.relationship('Order', backref='customer', lazy=True, 
                                     foreign_keys='Order.customer_id')
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
        
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'role': self.role,
            'business_id': self.business_id,
            'business_name': self.business_name
        }

class Order(db.Model):
    __tablename__ = 'orders'

    id = db.Column(db.Integer, primary_key=True)
    product_name = db.Column(db.String(120), nullable=False)
    price = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default='pending')  # pending, confirmed, in_delivery, delivered
    business_id = db.Column(db.String(50), nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Payment details
    payment_intent_id = db.Column(db.String(255), nullable=True)
    payment_status = db.Column(db.String(20), default='pending')  # pending, succeeded, failed
    tip_amount = db.Column(db.Float, default=0.0)

    def to_dict(self):
        return {
            'id': self.id,
            'product_name': self.product_name,
            'price': self.price,
            'status': self.status,
            'business_id': self.business_id,
            'customer_id': self.customer_id,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
            'payment_status': self.payment_status,
            'tip_amount': self.tip_amount
        }
