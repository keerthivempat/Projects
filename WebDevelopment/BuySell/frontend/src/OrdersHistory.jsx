import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import Navbar from './Navbar';
import { Tabs, TabList, Tab, TabPanel } from 'react-tabs';
import { ShoppingBag, Clock, CheckCircle, RefreshCw, Package, DollarSign, User, FileText } from 'lucide-react';
import 'react-tabs/style/react-tabs.css';
import './OrdersHistory.css';

const OrdersHistory = () => {
    const [pendingOrders, setPendingOrders] = useState([]);
    const [completedOrders, setCompletedOrders] = useState([]);
    const [soldOrders, setSoldOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [regenerating, setRegenerating] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        fetchOrders();
    }, []);

    const fetchOrders = async () => {
        try {
            const token = localStorage.getItem('token');
            if (!token) {
                navigate('/login');
                return;
            }
    
            const buyerResponse = await axios.get('http://localhost:5000/api/orders/buyer', {
                headers: { Authorization: `Bearer ${token}` }
            });

            // Include orders with their OTPs in pending orders
            const pending = buyerResponse.data
                .filter(order => order.status === 'pending')
                .map(order => ({
                    ...order,
                    plainOtp: order.plainOtp // This will be populated from the backend
                }));
            const completed = buyerResponse.data.filter(order => order.status === 'completed');
            
            setPendingOrders(pending);
            setCompletedOrders(completed);

            const sellerResponse = await axios.get('http://localhost:5000/api/orders/seller', {
                headers: { Authorization: `Bearer ${token}` }
            });
            
            const completedSales = sellerResponse.data.filter(order => order.status === 'completed');
            setSoldOrders(completedSales);
            
            setLoading(false);
        } catch (error) {
            console.error('Error fetching orders:', error);
            setError('Failed to fetch orders');
            setLoading(false);
        }
    };

    const regenerateOtp = async (orderId) => {
        try {
            setRegenerating(true);
            const token = localStorage.getItem('token');
            
            const response = await axios.post(
                `http://localhost:5000/api/orders/regenerate-otp/${orderId}`,
                {},
                { headers: { Authorization: `Bearer ${token}` }}
            );

            // Update the OTP in the pending orders state
            setPendingOrders(prevOrders => prevOrders.map(order => {
                if (order._id === orderId) {
                    return {
                        ...order,
                        plainOtp: response.data.plainOtp
                    };
                }
                return order;
            }));

            alert('New OTP generated successfully!');
        } catch (error) {
            console.error('Error regenerating OTP:', error);
            alert('Failed to regenerate OTP. Please try again.');
        } finally {
            setRegenerating(false);
        }
    };
  const handleCompleteOrder = async (orderId) => {
    try {
      const token = localStorage.getItem('token');
      await axios.post(
        'http://localhost:5000/api/orders/complete',
        { orderId, otp },
        { headers: { Authorization: `Bearer ${token}` }}
      );
      
      setOtp('');
      setSelectedOrder(null);
      await fetchOrders(); // Refresh orders after completion
    } catch (error) {
      console.error('Error completing order:', error);
      alert(error.response?.data?.message || 'Error completing order');
    }
  };
  if (loading) return (
    <div>
        <Navbar />
        <div className="loading-container">
            <div className="spinner">
                <ShoppingBag className="loading-icon" size={40} />
            </div>
            <p className="loading-text">Loading your orders...</p>
        </div>
    </div>
);

if (error) return (
    <div>
        <Navbar />
        <div className="error-container">
            <div className="alert alert-danger fade-in">
                <h4>Error</h4>
                <p>{error}</p>
            </div>
        </div>
    </div>
);

const OrderCard = ({ order, isPending = false, isSale = false }) => (
    <div className="order-card">
        <div className="order-header">
            <div className="order-icon">
                {isPending ? <Clock /> : <CheckCircle />}
            </div>
            <h5 className="order-title">{order.itemId?.name || 'Product Unavailable'}</h5>
        </div>
        
        <div className="order-details">
            <div className="detail-item">
                <DollarSign size={18} />
                <span>₹{order.itemId?.price || 0} × {order.quantity}</span>
            </div>
            
            <div className="detail-item">
                <Package size={18} />
                <span>Total: ₹{(order.itemId?.price || 0) * order.quantity}</span>
            </div>
            
            <div className="detail-item">
                <User size={18} />
                <span>
                    {isSale ? 'Buyer: ' : 'Seller: '}
                    {isSale 
                        ? `${order.buyerId?.firstName} ${order.buyerId?.lastName}`
                        : `${order.sellerId?.firstName} ${order.sellerId?.lastName}`
                    }
                </span>
            </div>
            
            <div className="detail-item">
                <FileText size={18} />
                <span>ID: {order._id}</span>
            </div>

            {isPending && (
                <div className="otp-section">
                    <div className="otp-content">
                        <h6>Transaction OTP</h6>
                        <div className="otp-display">{order.plainOtp}</div>
                        <small>Share this OTP with the seller</small>
                    </div>
                    <button 
                        className="btn btn-outline-primary btn-regenerate"
                        onClick={() => regenerateOtp(order._id)}
                        disabled={regenerating}
                    >
                        <RefreshCw size={16} className={regenerating ? 'spin' : ''} />
                        {regenerating ? 'Regenerating...' : 'Regenerate OTP'}
                    </button>
                </div>
            )}
        </div>
    </div>
);

return (
    <div>
        <Navbar />
        <div className="orders-container">
            <div className="orders-header">
                <ShoppingBag className="header-icon" />
                <h2>Orders History</h2>
            </div>
            
            <Tabs className="custom-tabs">
                <TabList>
                    <Tab>
                        <Clock size={18} />
                        <span>Pending Orders</span>
                        <span className="badge">{pendingOrders.length}</span>
                    </Tab>
                    <Tab>
                        <ShoppingBag size={18} />
                        <span>Purchase History</span>
                        <span className="badge">{completedOrders.length}</span>
                    </Tab>
                    <Tab>
                        <DollarSign size={18} />
                        <span>Sales History</span>
                        <span className="badge">{soldOrders.length}</span>
                    </Tab>
                </TabList>

                <TabPanel>
                    <div className="orders-grid">
                        {pendingOrders.length === 0 ? (
                            <div className="no-orders">
                                <Clock size={40} />
                                <p>No pending orders</p>
                            </div>
                        ) : (
                            pendingOrders.map(order => (
                                <OrderCard key={order._id} order={order} isPending={true} />
                            ))
                        )}
                    </div>
                </TabPanel>

                <TabPanel>
                    <div className="orders-grid">
                        {completedOrders.length === 0 ? (
                            <div className="no-orders">
                                <ShoppingBag size={40} />
                                <p>No purchase history</p>
                            </div>
                        ) : (
                            completedOrders.map(order => (
                                <OrderCard key={order._id} order={order} />
                            ))
                        )}
                    </div>
                </TabPanel>

                <TabPanel>
                    <div className="orders-grid">
                        {soldOrders.length === 0 ? (
                            <div className="no-orders">
                                <DollarSign size={40} />
                                <p>No sales history</p>
                            </div>
                        ) : (
                            soldOrders.map(order => (
                                <OrderCard key={order._id} order={order} isSale={true} />
                            ))
                        )}
                    </div>
                </TabPanel>
            </Tabs>
        </div>
    </div>
);
};

export default OrdersHistory;