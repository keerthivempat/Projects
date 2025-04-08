import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { User, Mail, Phone, Calendar, Edit2, LogOut, Save, X } from 'lucide-react';
import Navbar from './Navbar';
import 'bootstrap/dist/css/bootstrap.min.css';
import './Profile.css';

const Profile = () => {
  const [profile, setProfile] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    age: '',
    contactNumber: '',
  });
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/auth', { replace: true });
      return;
    }

    const fetchProfile = async () => {
      try {
        const response = await axios.get('http://localhost:5000/api/profile', {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        setProfile(response.data);
        setFormData(response.data);
      } catch (error) {
        localStorage.removeItem('token');
        navigate('/auth', { replace: true });
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, [navigate]);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    navigate('/login');
  };

  const handleEditClick = () => {
    setIsEditing(true);
  };

  const handleCancelEdit = () => {
    setFormData(profile);
    setIsEditing(false);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prevData => ({
      ...prevData,
      [name]: value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    try {
      const response = await axios.put('http://localhost:5000/api/profile', formData, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      setProfile(response.data);
      setIsEditing(false);
    } catch (error) {
      console.error("Error updating profile:", error);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="profile-page">
      <Navbar />
      <div className="container py-5">
        <div className="row justify-content-center">
          <div className="col-md-8 col-lg-6">
            <div className="profile-card">
              <div className="profile-header">
                <div className="profile-avatar">
                  {profile.firstName.charAt(0)}{profile.lastName.charAt(0)}
                </div>
                <h2 className="profile-title">
                  {profile.firstName} {profile.lastName}
                </h2>
                <p className="profile-subtitle">IIIT Student</p>
              </div>

              <div className="profile-content">
                {isEditing ? (
                  <form onSubmit={handleSubmit} className="edit-form">
                    <div className="form-floating mb-3">
                      <input
                        type="text"
                        className="form-control"
                        id="firstName"
                        name="firstName"
                        placeholder="First Name"
                        value={formData.firstName}
                        onChange={handleInputChange}
                      />
                      <label htmlFor="firstName">First Name</label>
                    </div>

                    <div className="form-floating mb-3">
                      <input
                        type="text"
                        className="form-control"
                        id="lastName"
                        name="lastName"
                        placeholder="Last Name"
                        value={formData.lastName}
                        onChange={handleInputChange}
                      />
                      <label htmlFor="lastName">Last Name</label>
                    </div>

                    <div className="form-floating mb-3">
                      <input
                        type="email"
                        className="form-control"
                        id="email"
                        name="email"
                        placeholder="Email"
                        value={formData.email}
                        onChange={handleInputChange}
                      />
                      <label htmlFor="email">Email</label>
                    </div>

                    <div className="form-floating mb-3">
                      <input
                        type="number"
                        className="form-control"
                        id="age"
                        name="age"
                        placeholder="Age"
                        value={formData.age}
                        onChange={handleInputChange}
                      />
                      <label htmlFor="age">Age</label>
                    </div>

                    <div className="form-floating mb-4">
                      <input
                        type="text"
                        className="form-control"
                        id="contactNumber"
                        name="contactNumber"
                        placeholder="Contact Number"
                        value={formData.contactNumber}
                        onChange={handleInputChange}
                      />
                      <label htmlFor="contactNumber">Contact Number</label>
                    </div>

                    <div className="d-flex gap-2">
                      <button type="submit" className="btn btn-success flex-grow-1">
                        <Save size={18} className="me-2" />
                        Save Changes
                      </button>
                      <button 
                        type="button" 
                        className="btn btn-outline-secondary flex-grow-1"
                        onClick={handleCancelEdit}
                      >
                        <X size={18} className="me-2" />
                        Cancel
                      </button>
                    </div>
                  </form>
                ) : (
                  <div className="profile-info">
                    <div className="info-item">
                      <User className="info-icon" />
                      <div className="info-content">
                        <span className="info-label">Full Name</span>
                        <span className="info-value">{profile.firstName} {profile.lastName}</span>
                      </div>
                    </div>

                    <div className="info-item">
                      <Mail className="info-icon" />
                      <div className="info-content">
                        <span className="info-label">Email</span>
                        <span className="info-value">{profile.email}</span>
                      </div>
                    </div>

                    <div className="info-item">
                      <Calendar className="info-icon" />
                      <div className="info-content">
                        <span className="info-label">Age</span>
                        <span className="info-value">{profile.age} years</span>
                      </div>
                    </div>

                    <div className="info-item">
                      <Phone className="info-icon" />
                      <div className="info-content">
                        <span className="info-label">Contact</span>
                        <span className="info-value">{profile.contactNumber}</span>
                      </div>
                    </div>

                    <div className="profile-actions">
                      <button className="btn btn-primary w-100 mb-2" onClick={handleEditClick}>
                        <Edit2 size={18} className="me-2" />
                        Edit Profile
                      </button>
                      <button className="btn btn-danger w-100" onClick={handleLogout}>
                        <LogOut size={18} className="me-2" />
                        Logout
                      </button>
                    </div>
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

export default Profile;