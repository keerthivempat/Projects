import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useParams, useNavigate } from 'react-router-dom';
import Navbar from './Navbar';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'animate.css';
import { Star, ShoppingCart, Package, Award, TrendingUp, AlertTriangle } from 'lucide-react';

const ItemDetails = () => {
  const [item, setItem] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [imageLoaded, setImageLoaded] = useState(false);
  const { id } = useParams();
  const navigate = useNavigate();
  
  useEffect(() => {
    const token = localStorage.getItem('token');
    console.log('Current token:', token);
    fetchItemDetails();
  }, [id]);

  const fetchItemDetails = async () => {
    try {
      const response = await axios.get(`http://localhost:5000/api/items/${id}`);
      setItem(response.data);
      setLoading(false);
    } catch (error) {
      setError('Error fetching item details');
      setLoading(false);
    }
  };

  const addToCart = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        navigate('/login');
        return;
      }
  
      await axios.post('http://localhost:5000/api/cart/add', 
        {
          itemId: id,
          quantity: quantity
        }, 
        {
          headers: { 
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        }
      );
  
      alert('Item added to cart successfully!');
    } catch (error) {
      if (error.response) {
        if (error.response.status === 401) {
          alert('Please login to add items to cart');
          navigate('/login');
        } else {
          alert(error.response.data.message || 'Error adding item to cart');
        }
      } else {
        alert('Error adding item to cart');
      }
      console.error('Add to cart error:', error);
    }
  };

  if (loading) return (
    <div className="min-vh-100 d-flex justify-content-center align-items-center">
      <div className="spinner-border text-primary" role="status">
        <span className="visually-hidden">Loading...</span>
      </div>
    </div>
  );
  
  if (error) return (
    <div className="min-vh-100 d-flex justify-content-center align-items-center text-danger">
      <AlertTriangle className="me-2" />{error}
    </div>
  );
  
  if (!item) return (
    <div className="min-vh-100 d-flex justify-content-center align-items-center text-warning">
      <AlertTriangle className="me-2" />Item not found
    </div>
  );

  return (
    <div className="min-vh-100 bg-light">
      <Navbar />
      <div className="container py-5">
        <div className="card border-0 shadow-lg animate__animated animate__fadeIn">
          <div className="row g-0">
            <div className="col-md-6 p-4">
              <div className="position-relative">
                <img 
                  src={item.imageUrl || 'https://via.placeholder.com/400'}
                  alt={item.name}
                  className={`img-fluid rounded-3 shadow ${imageLoaded ? 'animate__animated animate__fadeIn' : 'd-none'}`}
                  onLoad={() => setImageLoaded(true)}
                />
                {!imageLoaded && (
                  <div className="placeholder-glow w-100 h-100">
                    <div className="placeholder w-100" style={{height: '400px'}}></div>
                  </div>
                )}
                {item.stockQuantity < 5 && item.stockQuantity > 0 && (
                  <div className="position-absolute top-0 end-0 m-3">
                    <span className="badge bg-warning animate__animated animate__pulse animate__infinite">
                      Only {item.stockQuantity} left!
                    </span>
                  </div>
                )}
              </div>
            </div>
            <div className="col-md-6 p-4">
              <div className="h-100 d-flex flex-column">
                <div className="mb-4">
                  <h1 className="display-5 fw-bold mb-3 animate__animated animate__fadeInRight">
                    {item.name}
                  </h1>
                  <div className="d-flex align-items-center mb-3 animate__animated animate__fadeInRight animate__delay-1s">
                    <h3 className="text-primary mb-0">₹{item.price.toLocaleString()}</h3>
                    {item.stockQuantity > 0 ? (
                      <span className="badge bg-success ms-3">In Stock</span>
                    ) : (
                      <span className="badge bg-danger ms-3">Out of Stock</span>
                    )}
                  </div>
                </div>

                <div className="mb-4 animate__animated animate__fadeInRight animate__delay-0.5s">
                  <div className="d-flex align-items-center mb-3">
                    <Package className="text-primary me-2" />
                    <span className="text-muted">Category: {item.category}</span>
                  </div>
                  <div className="d-flex align-items-center">
                    <Award className="text-primary me-2" />
                    <span className="text-muted">Seller: {item.vendorName}</span>
                  </div>
                </div>

                <div className="mb-4 animate__animated animate__fadeInRight animate__delay-0.5s">
                  <h5 className="d-flex align-items-center">
                    <Star className="text-primary me-2" />
                    Description
                  </h5>
                  <p className="lead">{item.description}</p>
                </div>

                <div className="mt-auto animate__animated animate__fadeInUp animate__delay-0.5s">
                  <div className="d-flex align-items-center mb-3">
                    <div className="input-group" style={{maxWidth: "200px"}}>
                      <span className="input-group-text">Qty</span>
                      <input
                        type="number"
                        className="form-control"
                        value={quantity}
                        onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
                        min="1"
                        max={item.stockQuantity}
                      />
                    </div>
                  </div>

                  <button 
                    className="btn btn-primary btn-lg w-100 d-flex align-items-center justify-content-center"
                    onClick={addToCart}
                    disabled={item.stockQuantity < 1}
                  >
                    <ShoppingCart className="me-2" />
                    Add to Cart
                  </button>
                  
                  {item.stockQuantity < 1 && (
                    <div className="alert alert-danger d-flex align-items-center mt-3" role="alert">
                      <AlertTriangle className="me-2" />
                      This item is currently out of stock
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ItemDetails;