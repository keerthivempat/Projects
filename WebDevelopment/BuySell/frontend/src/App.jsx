import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';

import Sign from './Sign';
import Login from './Login';
import Profile from './Profile';
import Auth from './Auth';
import SearchItems from './SearchItems';
import ItemDetails from './ItemDetails';
import MyCart from './MyCart';
import DeliverItems from './DeliverItems';
import OrdersHistory from './OrdersHistory';
import Support from './Support';
// Protected Route Component
const ProtectedRoute = ({ children }) => {
  const token = localStorage.getItem('token');
  return token ? children : <Navigate to="/auth" replace />;
};

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Sign />} />
        <Route path="/register" element={<Sign />} />
        <Route path="/login" element={<Login />} />
        <Route 
            path="/cart" 
            element={
              <ProtectedRoute>
                <MyCart />
              </ProtectedRoute>
            } 
          />
        <Route 
            path="/orders-history" 
            element={
              <ProtectedRoute>
                <OrdersHistory />
              </ProtectedRoute>
            } 
          />
        <Route 
            path="/deliver-items" 
            element={
              <ProtectedRoute>
                <DeliverItems />
              </ProtectedRoute>
            } 
          />
        <Route 
            path="/items/:id" 
            element={
              <ProtectedRoute>
                <ItemDetails />
              </ProtectedRoute>
            } 
          />
        <Route 
            path="/support" 
            element={
              <ProtectedRoute>
                <Support />
              </ProtectedRoute>
            } 
          />

        <Route 
          path="/profile" 
          element={
            <ProtectedRoute>
              <Profile />
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/search-items" 
          element={
            <ProtectedRoute>
              <SearchItems />
            </ProtectedRoute>
          } 
        />
        <Route path="/auth" element={<Auth />} />
        {/* Catch-all route to redirect to auth page */}
        <Route path="*" element={<Navigate to="/auth" replace />} />
      </Routes>
    </Router>
  );
}

export default App;