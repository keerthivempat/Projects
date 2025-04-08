import React from 'react';
import { useNavigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';

const Auth = () => {
  const navigate = useNavigate();

  return (
    <div className="container mt-5">
      <div className="row justify-content-center">
        <div className="col-md-6">
          <div className="card">
            <div className="card-header text-center">
              <h2>Authentication Required</h2>
            </div>
            <div className="card-body">
              <p className="text-center">Please register or login to access the application.</p>
              <div className="d-flex justify-content-center">
                <button 
                  className="btn btn-success" 
                  onClick={() => navigate('/register')}
                >
                  Go to Registration
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Auth;