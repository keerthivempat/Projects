import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import Navbar from './Navbar';

const DeliverItems = () => {
  const [pendingDeliveries, setPendingDeliveries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [otpInputs, setOtpInputs] = useState({});
  const navigate = useNavigate();

  useEffect(() => {
    fetchPendingDeliveries();
  }, []);

  const fetchPendingDeliveries = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        navigate('/auth');
        return;
      }

      const response = await axios.get('http://localhost:5000/api/orders/seller', {
        headers: { Authorization: `Bearer ${token}` }
      });

      const pendingOrders = response.data.filter(order => order.status === 'pending');
      setPendingDeliveries(pendingOrders);
      
      const inputs = {};
      pendingOrders.forEach(order => {
        inputs[order._id] = '';
      });
      setOtpInputs(inputs);
      
      setLoading(false);
    } catch (error) {
      console.error('Error fetching deliveries:', error);
      setLoading(false);
    }
  };

  const handleOtpChange = (orderId, value) => {
    setOtpInputs(prev => ({
      ...prev,
      [orderId]: value
    }));
  };

  const completeDelivery = async (orderId) => {
    try {
      const token = localStorage.getItem('token');
      const otp = otpInputs[orderId];

      if (!otp) {
        alert('Please enter OTP');
        return;
      }

      await axios.post('http://localhost:5000/api/orders/complete', 
        { orderId, otp },
        { headers: { Authorization: `Bearer ${token}` }}
      );

      setOtpInputs(prev => ({
        ...prev,
        [orderId]: ''
      }));

      await fetchPendingDeliveries();
      
      // Show success toast
      const toastElement = document.getElementById('successToast');
      const toast = new bootstrap.Toast(toastElement);
      toast.show();
    } catch (error) {
      if (error.response?.status === 400) {
        alert('Invalid OTP. Please check and try again.');
      } else {
        alert('Error completing delivery. Please try again.');
      }
      console.error('Error completing delivery:', error);
    }
  };

  if (loading) return (
    <div>
      <Navbar />
      <div className="container mt-5">
        <div className="d-flex justify-content-center">
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="bg-light min-vh-100">
      <Navbar />
      
      {/* Success Toast */}
      <div className="position-fixed bottom-0 end-0 p-3" style={{ zIndex: 11 }}>
        <div id="successToast" className="toast align-items-center text-white bg-success border-0" role="alert" aria-live="assertive" aria-atomic="true">
          <div className="d-flex">
            <div className="toast-body">
              Delivery completed successfully!
            </div>
            <button type="button" className="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
          </div>
        </div>
      </div>

      <div className="container mt-5 pb-5">
        <div className="row justify-content-center">
          <div className="col-12 col-lg-10">
            <div className="card shadow-lg border-0 rounded-3 animate__animated animate__fadeIn">
              <div className="card-header bg-primary text-white">
                <h2 className="mb-0 py-2">Pending Deliveries</h2>
              </div>
              <div className="card-body p-4">
                {pendingDeliveries.length === 0 ? (
                  <div className="alert alert-info animate__animated animate__fadeIn">
                    No pending deliveries
                  </div>
                ) : (
                  <div className="delivery-list">
                    {pendingDeliveries.map((delivery, index) => (
                      <div 
                        key={delivery._id} 
                        className="card mb-4 border-0 shadow-sm animate__animated animate__fadeInUp"
                        style={{ animationDelay: `${index * 0.1}s` }}
                      >
                        <div className="card-body">
                          <div className="row">
                            <div className="col-md-8">
                              <h4 className="text-primary mb-3">{delivery.itemId?.name || 'Product Unavailable'}</h4>
                              <div className="row g-3">
                                <div className="col-6">
                                  <p className="mb-1"><strong>Price:</strong> ₹{delivery.itemId?.price || 0}</p>
                                  <p className="mb-1"><strong>Quantity:</strong> {delivery.quantity}</p>
                                  <p className="mb-1"><strong>Total:</strong> ₹{(delivery.itemId?.price || 0) * delivery.quantity}</p>
                                </div>
                                <div className="col-6">
                                  <p className="mb-1"><strong>Buyer:</strong> {delivery.buyerId?.firstName} {delivery.buyerId?.lastName}</p>
                                  <p className="mb-1"><strong>Email:</strong> {delivery.buyerId?.email}</p>
                                  <p className="mb-1"><strong>ID:</strong> {delivery._id}</p>
                                </div>
                              </div>
                            </div>
                            <div className="col-md-4">
                              <div className="mt-3 mt-md-0">
                                <div className="form-floating mb-3">
                                  <input
                                    type="text"
                                    className="form-control"
                                    id={`otp-${delivery._id}`}
                                    placeholder="Enter OTP"
                                    value={otpInputs[delivery._id] || ''}
                                    onChange={(e) => handleOtpChange(delivery._id, e.target.value)}
                                  />
                                  <label htmlFor={`otp-${delivery._id}`}>Enter OTP</label>
                                </div>
                                <button
                                  className="btn btn-primary w-100 position-relative overflow-hidden"
                                  onClick={() => completeDelivery(delivery._id)}
                                  disabled={!otpInputs[delivery._id]}
                                >
                                  <span className="d-flex align-items-center justify-content-center">
                                    <i className="bi bi-check2-circle me-2"></i>
                                    Complete Delivery
                                  </span>
                                </button>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DeliverItems;