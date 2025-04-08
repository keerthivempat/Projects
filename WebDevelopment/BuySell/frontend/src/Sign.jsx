import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ReCAPTCHA from 'react-google-recaptcha';
import axios from 'axios';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'animate.css';

const Sign = () => {
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    age: '',
    contactNumber: '',
    password: '',
    confirmPassword: ''
  });
  const [captchaValue, setCaptchaValue] = useState(null);
  const navigate = useNavigate();
  const RECAPTCHA_SITE_KEY = "6LcqOssqAAAAAE9ili7h648pENbzfiUVRVi2rVQs";
  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };
  const handleCaptchaChange = (value) => {
    setCaptchaValue(value);
  };
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!captchaValue) {
      alert('Please complete the reCAPTCHA verification');
      return;
    }
    if (formData.password !== formData.confirmPassword) {
      alert('Passwords do not match');
      return;
    }

    if (!formData.email.endsWith('@iiit.ac.in')) {
      alert('Only IIIT email addresses are allowed');
      return;
    }

    try {
      const response = await axios.post('http://localhost:5000/api/register', {
        firstName: formData.firstName,
        lastName: formData.lastName,
        email: formData.email,
        age: formData.age,
        contactNumber: formData.contactNumber,
        password: formData.password,
        recaptchaToken: captchaValue
      });

      alert(response.data.message);
      navigate('/login');
    } catch (error) {
      console.log(error);
      alert(error.response?.data?.message || 'Registration failed');
    }
  };

  return (
    <div className="min-vh-100 d-flex align-items-center py-5" 
         style={{
           background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
           minHeight: '100vh'
         }}>
      <div className="container">
        <div className="row justify-content-center">
          <div className="col-md-8 col-lg-6">
            <div className="card border-0 shadow-lg animate__animated animate__fadeIn">
              <div className="card-header bg-transparent border-bottom-0 text-center pt-4">
                <h1 className="text-primary fw-bold mb-3">Create Account</h1>
                <p className="text-muted">Join our community today!</p>
              </div>
              <div className="card-body px-4 py-5">
                <form onSubmit={handleSubmit} className="animate__animated animate__fadeInUp">
                  <div className="row g-3">
                    <div className="col-md-6">
                      <div className="form-floating mb-3">
                        <input
                          type="text"
                          className="form-control"
                          id="firstName"
                          name="firstName"
                          placeholder="First Name"
                          value={formData.firstName}
                          onChange={handleChange}
                          required
                        />
                        <label htmlFor="firstName">First Name</label>
                      </div>
                    </div>
                    <div className="col-md-6">
                      <div className="form-floating mb-3">
                        <input
                          type="text"
                          className="form-control"
                          id="lastName"
                          name="lastName"
                          placeholder="Last Name"
                          value={formData.lastName}
                          onChange={handleChange}
                          required
                        />
                        <label htmlFor="lastName">Last Name</label>
                      </div>
                    </div>
                  </div>

                  <div className="form-floating mb-3">
                    <input
                      type="email"
                      className="form-control"
                      id="email"
                      name="email"
                      placeholder="name@iiit.ac.in"
                      value={formData.email}
                      onChange={handleChange}
                      required
                    />
                    <label htmlFor="email">IIIT Email Address</label>
                  </div>

                  <div className="row g-3">
                    <div className="col-md-6">
                      <div className="form-floating mb-3">
                        <input
                          type="number"
                          className="form-control"
                          id="age"
                          name="age"
                          placeholder="Age"
                          value={formData.age}
                          onChange={handleChange}
                          required
                        />
                        <label htmlFor="age">Age</label>
                      </div>
                    </div>
                    <div className="col-md-6">
                      <div className="form-floating mb-3">
                        <input
                          type="tel"
                          className="form-control"
                          id="contactNumber"
                          name="contactNumber"
                          placeholder="Contact Number"
                          value={formData.contactNumber}
                          onChange={handleChange}
                          required
                        />
                        <label htmlFor="contactNumber">Contact Number</label>
                      </div>
                    </div>
                  </div>

                  <div className="form-floating mb-3">
                    <input
                      type="password"
                      className="form-control"
                      id="password"
                      name="password"
                      placeholder="Password"
                      value={formData.password}
                      onChange={handleChange}
                      required
                    />
                    <label htmlFor="password">Password</label>
                  </div>

                  <div className="form-floating mb-4">
                    <input
                      type="password"
                      className="form-control"
                      id="confirmPassword"
                      name="confirmPassword"
                      placeholder="Confirm Password"
                      value={formData.confirmPassword}
                      onChange={handleChange}
                      required
                    />
                    <label htmlFor="confirmPassword">Confirm Password</label>
                  </div>
                  <div className="mb-4 d-flex justify-content-center">
                    <ReCAPTCHA
                      sitekey={RECAPTCHA_SITE_KEY}
                      onChange={handleCaptchaChange}
                    />
                  </div>
                  <button
                    type="submit"
                    className="btn btn-primary w-100 py-3 mb-4 animate__animated animate__pulse animate__infinite"
                  >
                    Create Account
                  </button>
                </form>

                <div className="text-center animate__animated animate__fadeIn">
                  <p className="text-muted mb-3">Already have an account?</p>
                  <button
                    className="btn btn-outline-primary px-4"
                    onClick={() => navigate('/login')}
                  >
                    Login
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Sign;