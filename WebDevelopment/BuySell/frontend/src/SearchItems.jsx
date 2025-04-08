import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link, useNavigate } from 'react-router-dom';
import Navbar from './Navbar';
import 'bootstrap/dist/css/bootstrap.min.css';
import './SearchItems.css';

const categories = [
  'Electronics', 'Books', 'Clothing', 'Furniture', 
  'Stationery', 'Sports', 'Miscellaneous'
];

const SearchItems = () => {
  const [items, setItems] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategories, setSelectedCategories] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const navigate = useNavigate();

  // Create a debounced search term
  const debouncedSearch = React.useCallback(
    debounce((search, categories) => {
      fetchItems(search, categories);
    }, 500),
    []
  );

  // Separate useEffect for search/category changes
  useEffect(() => {
    debouncedSearch(searchTerm, selectedCategories);
    // Cleanup
    return () => debouncedSearch.cancel();
  }, [searchTerm, selectedCategories, debouncedSearch]);

  const fetchItems = async (search, categories) => {
    try {
      setIsLoading(true);
      const params = new URLSearchParams();
      if (search) params.append('search', search);
      if (categories.length) params.append('categories', categories.join(','));

      const token = localStorage.getItem('token');
      
      const response = await axios.get(
        `http://localhost:5000/api/items?${params.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      setItems(response.data);
    } catch (error) {
      console.error('Error fetching items:', error);
      setItems([]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCategoryToggle = (category) => {
    setSelectedCategories(prev => 
      prev.includes(category) 
        ? prev.filter(c => c !== category)
        : [...prev, category]
    );
  };

  return (
    <div>
      <Navbar />
      <div className="container mt-4">
        <div className="row">
          {/* Sidebar for Categories */}
          <div className="col-md-3">
            <h5 className="category-title">Categories</h5>
            {categories.map(category => (
              <div 
                key={category} 
                className="form-check category-item"
              >
                <input
                  type="checkbox"
                  className="form-check-input"
                  id={category}
                  checked={selectedCategories.includes(category)}
                  onChange={() => handleCategoryToggle(category)}
                />
                <label className="form-check-label" htmlFor={category}>
                  {category}
                </label>
              </div>
            ))}
          </div>

          {/* Main Content */}
          <div className="col-md-9">
            {/* Search Input */}
            <input
              type="text"
              className="form-control mb-3 search-bar"
              placeholder="Search items..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />

            {/* Items Grid */}
            <div className="row">
              {isLoading ? (
                <div className="col-12 text-center">
                  <p>Loading items...</p>
                </div>
              ) : items.length > 0 ? (
                items.map((item) => (
                  <div key={item._id} className="col-md-4 mb-3">
                    <div className="card h-100 item-card fade-in">
                      <img 
                        src={item.imageUrl || 'https://via.placeholder.com/150'} 
                        className="card-img-top"
                        alt={item.name}
                        style={{ height: '200px', objectFit: 'cover' }}
                      />
                      <div className="card-body">
                        <h5 className="card-title">{item.name}</h5>
                        <p className="card-text price">₹{item.price}</p>
                        <p className="card-text"><small>Category: {item.category}</small></p>
                        <p className="card-text text-muted">
                          Seller: {item.vendorName}
                        </p>
                        <Link 
                          to={`/items/${item._id}`} 
                          className="btn btn-primary view-details-btn"
                        >
                          View Details
                        </Link>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="col-12 text-center">
                  <p className="text-muted">No items found.</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// Debounce helper function
function debounce(func, wait) {
  let timeout;
  const debouncedFunction = function(...args) {
    const context = this;
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(context, args), wait);
  };
  debouncedFunction.cancel = function() {
    clearTimeout(timeout);
  };
  return debouncedFunction;
}

export default SearchItems;