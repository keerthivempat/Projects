import React from 'react';
import Navbar from './Navbar';
import './Support.css';
import 'bootstrap/dist/css/bootstrap.min.css';

const Support = () => {
  const [messages, setMessages] = React.useState([]);
  const [inputMessage, setInputMessage] = React.useState('');
  const [isLoading, setIsLoading] = React.useState(false);
  const messagesEndRef = React.useRef(null);
  

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };
  const isFirstRender = React.useRef(true);
  React.useEffect(() => {
    scrollToBottom();
  }, [messages]);

  React.useEffect(() => {
    if (isFirstRender.current) {
      handleBotResponse("Hello! I'm your IIIT Buy-Sell assistant. How can I help you today?");
      isFirstRender.current = false;
    }
  }, []);

  const handleBotResponse = (content) => {
    setMessages(prev => [...prev, {
      type: 'bot',
      content,
      timestamp: new Date().toISOString()
    }]);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!inputMessage.trim()) return;

    const userMessage = {
      type: 'user',
      content: inputMessage,
      timestamp: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);

    try {
      const token = localStorage.getItem('token');
      if (!token) {
        navigate('/auth');
        return;
      }
      const response = await fetch('http://localhost:5000/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          message: inputMessage,
        }),
      });

      if (!response.ok) {
        throw new Error('Network response was not ok');
      }

      const data = await response.json();
      handleBotResponse(data.response);
    } catch (error) {
      console.error('Chat error:', error);
      handleBotResponse("I'm sorry, I'm having trouble connecting right now. Please try again later.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="d-flex flex-column min-vh-100">
      <Navbar />
      <div className="container py-4 flex-grow-1">
        <div className="row justify-content-center">
          <div className="col-md-8">
            <div className="card shadow">
              <div className="card-header bg-primary text-white">
                <h5 className="mb-0">Support Chat</h5>
              </div>
              
              {/* Chat messages area */}
              <div 
                className="card-body" 
                style={{ 
                  height: 'calc(100vh - 300px)', 
                  overflowY: 'auto',
                  backgroundColor: '#f8f9fa'
                }}
              >
                {messages.map((message, index) => (
                  <div 
                    key={index} 
                    className={`d-flex mb-3 ${message.type === 'user' ? 'justify-content-end' : 'justify-content-start'}`}
                  >
                    <div 
                      className={`d-flex align-items-start ${message.type === 'user' ? 'flex-row-reverse' : 'flex-row'}`}
                      style={{ maxWidth: '75%' }}
                    >
                      {/* Avatar */}
                      <div 
                        className={`rounded-circle d-flex align-items-center justify-content-center ${
                          message.type === 'user' ? 'bg-primary' : 'bg-secondary'
                        }`} 
                        style={{ width: '32px', height: '32px', minWidth: '32px' }}
                      >
                        <small className="text-white">
                          {message.type === 'user' ? 'U' : 'B'}
                        </small>
                      </div>

                      {/* Message bubble */}
                      <div 
                        className={`mx-2 p-3 rounded ${
                          message.type === 'user'
                            ? 'bg-primary text-white'
                            : 'bg-white border'
                        }`}
                      >
                        {message.content}
                      </div>
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>

              {/* Input form */}
              <div className="card-footer bg-white">
                <form onSubmit={handleSubmit} className="d-flex gap-2">
                  <input
                    type="text"
                    value={inputMessage}
                    onChange={(e) => setInputMessage(e.target.value)}
                    placeholder="Type your message..."
                    disabled={isLoading}
                    className="form-control"
                  />
                  <button
                    type="submit"
                    disabled={isLoading}
                    className="btn btn-primary px-4"
                  >
                    {isLoading ? (
                      <span className="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
                    ) : (
                      'Send'
                    )}
                  </button>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Support;