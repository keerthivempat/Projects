import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import Navbar from './Navbar';
import 'bootstrap/dist/css/bootstrap.min.css';

const MyCart = () => {
  const [cartItems, setCartItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalCost, setTotalCost] = useState(0);
  const navigate = useNavigate();
  const currentUserId = localStorage.getItem('userId');

  useEffect(() => {
    fetchCartItems();
  }, []);

  const fetchCartItems = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        navigate('/login');
        return;
      }

      const response = await axios.get('http://localhost:5000/api/cart', {
        headers: { Authorization: `Bearer ${token}` }
      });

      const filteredItems = response.data.cart?.items.filter(item => 
        item.itemId.sellerId !== currentUserId
      ) || [];

      setCartItems(filteredItems);
      calculateTotal(filteredItems);
      setLoading(false);
    } catch (error) {
      setError('Error fetching cart items');
      setLoading(false);
    }
  };

  const calculateTotal = (items) => {
    const total = items.reduce((sum, item) => {
      return sum + (item.itemId.price * item.quantity);
    }, 0);
    setTotalCost(total);
  };

  const removeFromCart = async (itemId) => {
    try {
      const token = localStorage.getItem('token');
      await axios.delete(`http://localhost:5000/api/cart/remove/${itemId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });

      const updatedItems = cartItems.filter(item => item.itemId._id !== itemId);
      setCartItems(updatedItems);
      calculateTotal(updatedItems);
      
      // Show success toast
      const toastElement = document.getElementById('removeToast');
      const toast = new bootstrap.Toast(toastElement);
      toast.show();
    } catch (error) {
      alert('Error removing item from cart');
    }
  };

  const placeOrder = async () => {
    try {
      const token = localStorage.getItem('token');
      if (cartItems.length === 0) {
        alert('Your cart is empty');
        return;
      }

      const response = await axios.post('http://localhost:5000/api/orders/place', {
        items: cartItems
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });

      if (response.data.orders && response.data.orders.length > 0) {
        await axios.delete('http://localhost:5000/api/cart/clear', {
          headers: { Authorization: `Bearer ${token}` }
        });

        setCartItems([]);
        setTotalCost(0);
        
        const otpMessage = response.data.orders.map(order => 
          `Order placed successfully!\nOrder ID: ${order._id}\nOTP: ${order.plainOtp}`
        ).join('\n\n');
        
        alert(otpMessage);
        navigate('/orders-history');
      } else {
        alert('Error: No orders were created');
      }
    } catch (error) {
      console.error('Error placing order:', error);
      alert('Error placing order: ' + (error.response?.data?.message || 'Unknown error'));
    }
  };

  if (loading) return (
    <div>
      <Navbar />
      <div className="container mt-5 d-flex justify-content-center">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    </div>
  );

  if (error) return (
    <div>
      <Navbar />
      <div className="container mt-5">
        <div className="alert alert-danger animate__animated animate__fadeIn" role="alert">
          <i className="bi bi-exclamation-triangle-fill me-2"></i>
          {error}
        </div>
      </div>
    </div>
  );

  return (
    <div className="bg-light min-vh-100">
      <Navbar />
      
      {/* Remove Item Toast */}
      <div className="position-fixed bottom-0 end-0 p-3" style={{ zIndex: 11 }}>
        <div id="removeToast" className="toast align-items-center text-white bg-success border-0" role="alert" aria-atomic="true">
          <div className="d-flex">
            <div className="toast-body">
              <i className="bi bi-check-circle-fill me-2"></i>
              Item removed successfully!
            </div>
            <button type="button" className="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
          </div>
        </div>
      </div>

      <div className="container mt-5 pb-5">
        <div className="row justify-content-center">
          <div className="col-12 col-lg-10">
            <div className="card shadow-lg border-0 rounded-3 animate__animated animate__fadeIn">
              <div className="card-header bg-primary text-white d-flex justify-content-between align-items-center">
                <h2 className="mb-0 py-2">
                  <i className="bi bi-cart3 me-2"></i>
                  My Cart
                </h2>
                <span className="badge bg-white text-primary rounded-pill">
                  {cartItems.length} items
                </span>
              </div>
              
              <div className="card-body p-4">
                {cartItems.length === 0 ? (
                  <div className="text-center py-5 animate__animated animate__fadeIn">
                    <i className="bi bi-cart-x display-1 text-muted mb-4"></i>
                    <h3 className="text-muted">Your cart is empty</h3>
                    <button 
                      className="btn btn-primary mt-3"
                      onClick={() => navigate('/')}
                    >
                      Continue Shopping
                    </button>
                  </div>
                ) : (
                  <>
                    <div className="list-group mb-4">
                      {cartItems.map((item, index) => (
                        <div 
                          key={item.itemId._id} 
                          className="list-group-item border-0 shadow-sm mb-3 animate__animated animate__fadeInUp"
                          style={{ animationDelay: `${index * 0.1}s` }}
                        >
                          <div className="row align-items-center">
                            <div className="col-md-8">
                              <h4 className="text-primary mb-3">{item.itemId.name}</h4>
                              <div className="row g-3">
                                <div className="col-6 col-md-4">
                                  <div className="d-flex align-items-center">
                                    <i className="bi bi-tag-fill text-muted me-2"></i>
                                    <span>₹{item.itemId.price}</span>
                                  </div>
                                </div>
                                <div className="col-6 col-md-4">
                                  <div className="d-flex align-items-center">
                                    <i className="bi bi-boxes text-muted me-2"></i>
                                    <span>Qty: {item.quantity}</span>
                                  </div>
                                </div>
                                <div className="col-12 col-md-4">
                                  <div className="d-flex align-items-center">
                                    <i className="bi bi-currency-rupee text-muted me-2"></i>
                                    <span>₹{item.itemId.price * item.quantity}</span>
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div className="col-md-4 mt-3 mt-md-0 text-md-end">
                              <button
                                className="btn btn-outline-danger"
                                onClick={() => removeFromCart(item.itemId._id)}
                              >
                                <i className="bi bi-trash-fill me-2"></i>
                                Remove
                              </button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>

                    <div className="card border-0 shadow-sm mb-4 animate__animated animate__fadeInUp">
                      <div className="card-body">
                        <div className="d-flex justify-content-between align-items-center">
                          <h4 className="mb-0">Total Cost</h4>
                          <h3 className="mb-0 text-primary">₹{totalCost}</h3>
                        </div>
                      </div>
                    </div>

                    <div className="text-end animate__animated animate__fadeInUp">
                      <button
                        className="btn btn-primary btn-lg"
                        onClick={placeOrder}
                        disabled={cartItems.length === 0}
                      >
                        <i className="bi bi-bag-check-fill me-2"></i>
                        Place Order
                      </button>
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default MyCart;