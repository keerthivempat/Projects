import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';
import './Login.css'; // We'll create this file next
import { UserCircle, Lock } from 'lucide-react';

const Login = () => {
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [loading, setLoading] = useState(false);

  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const response = await axios.post('http://localhost:5000/api/login', formData);
      localStorage.setItem('token', response.data.token);
      localStorage.setItem('user', JSON.stringify(response.data.user));
      
      // Add success animation
      const form = e.target;
      form.classList.add('success');
      
      setTimeout(() => {
        navigate('/profile');
      }, 1500);
    } catch (error) {
      const form = e.target;
      form.classList.add('error');
      setTimeout(() => form.classList.remove('error'), 500);
      alert(error.response?.data?.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container vh-100 d-flex align-items-center justify-content-center bg-light">
      <div className="container">
        <div className="row justify-content-center">
          <div className="col-md-6 col-lg-4">
            <div className="card login-card shadow-lg border-0">
              <div className="card-body p-5">
                <div className="text-center mb-4">
                  <h2 className="login-title fw-bold text-primary mb-1">Welcome Back</h2>
                  <p className="text-muted">Please Login to continue</p>
                </div>
                
                <form onSubmit={handleSubmit} className="login-form">
                  <div className="form-floating mb-4">
                    <div className="input-group">
                      <span className="input-group-text bg-light border-end-0">
                        <UserCircle className="text-primary" size={20} />
                      </span>
                      <input 
                        type="email" 
                        className="form-control border-start-0 ps-0" 
                        name="email"
                        placeholder="IIIT Email"
                        value={formData.email}
                        onChange={handleChange}
                        required 
                      />
                    </div>
                  </div>
                  
                  <div className="form-floating mb-4">
                    <div className="input-group">
                      <span className="input-group-text bg-light border-end-0">
                        <Lock className="text-primary" size={20} />
                      </span>
                      <input 
                        type="password" 
                        className="form-control border-start-0 ps-0" 
                        name="password"
                        placeholder="Password"
                        value={formData.password}
                        onChange={handleChange}
                        required 
                      />
                    </div>
                  </div>
                  
                  <button 
                    type="submit" 
                    className="btn btn-primary w-100 py-3 mb-4 position-relative overflow-hidden"
                    disabled={loading}
                  >
                    {loading ? (
                      <div className="spinner-border spinner-border-sm" role="status">
                        <span className="visually-hidden">Loading...</span>
                      </div>
                    ) : (
                      'Login'
                    )}
                  </button>
                  
                  <div className="text-center">
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;