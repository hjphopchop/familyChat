import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './Home.css';

function Home() {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const createRoom = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      const data = await response.json();
      navigate(data.url);
    } catch (error) {
      console.error('Error creating room:', error);
      alert('Ошибка при создании комнаты');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="home-container">
      <div className="home-content">
        <h1 className="home-title">FamilyChat</h1>
        <p className="home-subtitle">Создайте комнату и пригласите участников</p>
        <button 
          className="create-room-btn" 
          onClick={createRoom}
          disabled={loading}
        >
          {loading ? 'Создание...' : 'Создать комнату'}
        </button>
      </div>
    </div>
  );
}

export default Home;

