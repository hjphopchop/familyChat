import React, { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import io from 'socket.io-client';
import './Room.css';

function Room() {
  const { roomId } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isVideoEnabled, setIsVideoEnabled] = useState(true);
  const [isAudioEnabled, setIsAudioEnabled] = useState(true);
  const [roomUrl, setRoomUrl] = useState('');
  const [showUrlCopied, setShowUrlCopied] = useState(false);

  const localVideoRef = useRef(null);
  const remoteVideosRef = useRef({});
  const socketRef = useRef(null);
  const peerConnectionsRef = useRef({});
  const localStreamRef = useRef(null);
  const iceCandidateQueueRef = useRef({});
  const currentUserIdRef = useRef(null);
  const [selectedVideoId, setSelectedVideoId] = useState(null);

  // Функция для обработки клика по видео
  const handleVideoClick = (userId) => {
    if (selectedVideoId === userId) {
      // Если кликнули на уже выбранное видео - снимаем выделение
      setSelectedVideoId(null);
    } else {
      // Выбираем новое видео
      setSelectedVideoId(userId);
    }
  };

  // Функция для обновления layout сетки видео
  const updateVideoGridLayout = () => {
    const remoteVideosContainer = document.getElementById('remote-videos');
    if (!remoteVideosContainer) return;

    const videoCount = Object.keys(remoteVideosRef.current).length;
    
    // Удаляем все классы layout
    remoteVideosContainer.classList.remove(
      'grid-1', 'grid-2', 'grid-3', 'grid-4', 'grid-5', 'grid-6', 'has-selected'
    );

    // Добавляем соответствующий класс
    if (videoCount > 0) {
      remoteVideosContainer.classList.add(`grid-${Math.min(videoCount, 6)}`);
    }

    // Обновляем классы для выбранного видео
    Object.keys(remoteVideosRef.current).forEach(videoId => {
      const video = remoteVideosRef.current[videoId];
      if (video) {
        if (selectedVideoId === videoId) {
          video.classList.add('selected');
        } else {
          video.classList.remove('selected');
        }
      }
    });

    // Добавляем класс контейнеру, если есть выбранное видео
    if (selectedVideoId) {
      remoteVideosContainer.classList.add('has-selected');
    }
  };

  // Обновляем layout при изменении выбранного видео
  useEffect(() => {
    updateVideoGridLayout();
  }, [selectedVideoId]);

  useEffect(() => {
    const url = `${window.location.origin}/room/${roomId}`;
    setRoomUrl(url);

    // Проверка существования комнаты
    fetch(`/api/rooms/${roomId}`)
      .then(res => res.json())
      .then(data => {
        if (!data.exists) {
          setError('Комната не найдена');
          setLoading(false);
          return;
        }
        initializeRoom();
      })
      .catch(err => {
        console.error('Error checking room:', err);
        setError('Ошибка при подключении к серверу');
        setLoading(false);
      });
  }, [roomId]);

  const initializeRoom = async () => {
    try {
      // Получаем медиапоток
      const stream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true
      });
      
      localStreamRef.current = stream;
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }

      // Подключаемся к Socket.io
      const socketUrl = process.env.NODE_ENV === 'production' 
        ? window.location.origin 
        : 'http://localhost:5000';
      socketRef.current = io(socketUrl);
      
      socketRef.current.on('connect', () => {
        currentUserIdRef.current = socketRef.current.id;
        socketRef.current.emit('join-room', roomId);
        setLoading(false);
      });

      socketRef.current.on('existing-users', (userIds) => {
        userIds.forEach(async (userId) => {
          // Проверяем, что это не мы сами и соединение еще не создано
          // Новый участник не создает offer, а ждет его от существующих участников
          if (userId !== currentUserIdRef.current && !peerConnectionsRef.current[userId]) {
            await createPeerConnection(userId, false);
          }
        });
      });

      socketRef.current.on('user-joined', async (userId) => {
        // Проверяем, что это не мы сами и соединение еще не создано
        // Когда к нам подключается новый участник, мы должны быть инициатором
        if (userId !== currentUserIdRef.current && !peerConnectionsRef.current[userId]) {
          // Небольшая задержка, чтобы новый участник успел создать соединение
          await new Promise(resolve => setTimeout(resolve, 200));
          await createPeerConnection(userId, true);
        }
      });

      socketRef.current.on('offer', async (data) => {
        const { offer, sender } = data;
        await handleOffer(offer, sender);
      });

      socketRef.current.on('answer', async (data) => {
        const { answer, sender } = data;
        await handleAnswer(answer, sender);
      });

      socketRef.current.on('ice-candidate', async (data) => {
        const { candidate, sender } = data;
        await handleIceCandidate(candidate, sender);
      });

      socketRef.current.on('user-left', (userId) => {
        if (peerConnectionsRef.current[userId]) {
          peerConnectionsRef.current[userId].close();
          delete peerConnectionsRef.current[userId];
        }
        if (remoteVideosRef.current[userId]) {
          const videoElement = remoteVideosRef.current[userId];
          // Останавливаем все треки
          if (videoElement.srcObject) {
            videoElement.srcObject.getTracks().forEach(track => track.stop());
          }
          // Удаляем элемент из DOM
          if (videoElement.parentNode) {
            videoElement.parentNode.removeChild(videoElement);
          }
          delete remoteVideosRef.current[userId];
          updateVideoGridLayout();
        }
        if (iceCandidateQueueRef.current[userId]) {
          delete iceCandidateQueueRef.current[userId];
        }
      });

      socketRef.current.on('error', (error) => {
        setError(error.message);
        setLoading(false);
      });

    } catch (err) {
      console.error('Error accessing media devices:', err);
      setError('Не удалось получить доступ к камере и микрофону');
      setLoading(false);
    }
  };

  const createPeerConnection = async (userId, isInitiator) => {
    // Если соединение уже существует, не создаем новое
    if (peerConnectionsRef.current[userId]) {
      return peerConnectionsRef.current[userId];
    }

    const peerConnection = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    });

    // Добавляем локальный поток
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach(track => {
        peerConnection.addTrack(track, localStreamRef.current);
      });
    }

    // Обработка удаленного потока
    peerConnection.ontrack = (event) => {
      const remoteStream = event.streams[0] || event.streams;
      
      // Проверяем, существует ли уже видео элемент для этого пользователя
      let remoteVideo = remoteVideosRef.current[userId];
      
      if (!remoteVideo) {
        // Создаем новый видео элемент только если его еще нет
        remoteVideo = document.createElement('video');
        remoteVideo.autoplay = true;
        remoteVideo.playsInline = true;
        remoteVideo.className = 'remote-video';
        remoteVideo.setAttribute('data-user-id', userId);
        remoteVideo.style.cursor = 'pointer';
        remoteVideo.addEventListener('click', () => handleVideoClick(userId));
        remoteVideosRef.current[userId] = remoteVideo;
        
        const remoteVideosContainer = document.getElementById('remote-videos');
        if (remoteVideosContainer) {
          // Проверяем, не добавлен ли уже этот элемент в DOM
          const existingElement = remoteVideosContainer.querySelector(`[data-user-id="${userId}"]`);
          if (!existingElement) {
            remoteVideosContainer.appendChild(remoteVideo);
            updateVideoGridLayout();
          }
        }
      }
      
      // Обновляем поток (может быть вызвано несколько раз для разных треков)
      if (remoteStream) {
        remoteVideo.srcObject = remoteStream;
      }
    };

    peerConnection.onicecandidate = (event) => {
      if (event.candidate && socketRef.current) {
        socketRef.current.emit('ice-candidate', {
          target: userId,
          candidate: event.candidate
        });
      }
    };

    peerConnectionsRef.current[userId] = peerConnection;
    iceCandidateQueueRef.current[userId] = [];

    // Обрабатываем очередь ICE кандидатов, если они есть
    if (iceCandidateQueueRef.current[userId]?.length > 0) {
      const queue = iceCandidateQueueRef.current[userId];
      iceCandidateQueueRef.current[userId] = [];
      queue.forEach(candidate => {
        if (peerConnection.remoteDescription) {
          peerConnection.addIceCandidate(new RTCIceCandidate(candidate)).catch(err => {
            console.error('Error adding queued ICE candidate:', err);
          });
        }
      });
    }

    if (isInitiator) {
      createOffer(userId);
    }

    return peerConnection;
  };

  const createOffer = async (userId) => {
    const peerConnection = peerConnectionsRef.current[userId];
    if (!peerConnection) {
      console.error('PeerConnection not found for user:', userId);
      return;
    }
    try {
      // Небольшая задержка, чтобы убедиться, что удаленная сторона готова
      await new Promise(resolve => setTimeout(resolve, 100));
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      if (socketRef.current) {
        socketRef.current.emit('offer', {
          target: userId,
          offer: offer
        });
      }
    } catch (err) {
      console.error('Error creating offer:', err);
    }
  };

  const handleOffer = async (offer, sender) => {
    try {
      let peerConnection = peerConnectionsRef.current[sender];
      if (!peerConnection) {
        peerConnection = await createPeerConnection(sender, false);
      }
      
      await peerConnection.setRemoteDescription(new RTCSessionDescription(offer));
      
      // Обрабатываем очередь ICE кандидатов после установки remote description
      if (iceCandidateQueueRef.current[sender]?.length > 0) {
        const queue = iceCandidateQueueRef.current[sender];
        iceCandidateQueueRef.current[sender] = [];
        for (const candidate of queue) {
          try {
            await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
          } catch (err) {
            console.error('Error adding queued ICE candidate:', err);
          }
        }
      }
      
      const answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      socketRef.current.emit('answer', {
        target: sender,
        answer: answer
      });
    } catch (err) {
      console.error('Error handling offer:', err);
    }
  };

  const handleAnswer = async (answer, sender) => {
    try {
      const peerConnection = peerConnectionsRef.current[sender];
      if (peerConnection) {
        await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
        
        // Обрабатываем очередь ICE кандидатов после установки remote description
        if (iceCandidateQueueRef.current[sender]?.length > 0) {
          const queue = iceCandidateQueueRef.current[sender];
          iceCandidateQueueRef.current[sender] = [];
          for (const candidate of queue) {
            try {
              await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
            } catch (err) {
              console.error('Error adding queued ICE candidate:', err);
            }
          }
        }
      }
    } catch (err) {
      console.error('Error handling answer:', err);
    }
  };

  const handleIceCandidate = async (candidate, sender) => {
    try {
      const peerConnection = peerConnectionsRef.current[sender];
      if (!peerConnection) {
        // Если соединение еще не создано, добавляем кандидата в очередь
        if (!iceCandidateQueueRef.current[sender]) {
          iceCandidateQueueRef.current[sender] = [];
        }
        iceCandidateQueueRef.current[sender].push(candidate);
        return;
      }

      // Если remote description еще не установлено, добавляем в очередь
      if (!peerConnection.remoteDescription) {
        if (!iceCandidateQueueRef.current[sender]) {
          iceCandidateQueueRef.current[sender] = [];
        }
        iceCandidateQueueRef.current[sender].push(candidate);
        return;
      }

      // Добавляем кандидата, если все готово
      await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
    } catch (err) {
      console.error('Error handling ICE candidate:', err);
    }
  };

  const toggleVideo = () => {
    if (localStreamRef.current) {
      const videoTrack = localStreamRef.current.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
        setIsVideoEnabled(videoTrack.enabled);
      }
    }
  };

  const toggleAudio = () => {
    if (localStreamRef.current) {
      const audioTrack = localStreamRef.current.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
        setIsAudioEnabled(audioTrack.enabled);
      }
    }
  };

  const copyRoomUrl = () => {
    navigator.clipboard.writeText(roomUrl).then(() => {
      setShowUrlCopied(true);
      setTimeout(() => setShowUrlCopied(false), 2000);
    });
  };

  const leaveRoom = () => {
    // Останавливаем все треки
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach(track => track.stop());
    }

    // Закрываем все peer connections
    Object.values(peerConnectionsRef.current).forEach(pc => pc.close());

    // Отключаемся от socket
    if (socketRef.current) {
      socketRef.current.disconnect();
    }

    navigate('/');
  };

  useEffect(() => {
    return () => {
      if (localStreamRef.current) {
        localStreamRef.current.getTracks().forEach(track => track.stop());
      }
      Object.values(peerConnectionsRef.current).forEach(pc => pc.close());
      if (socketRef.current) {
        socketRef.current.disconnect();
      }
    };
  }, []);

  if (loading) {
    return (
      <div className="room-container">
        <div className="loading">Подключение...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="room-container">
        <div className="error">{error}</div>
        <button className="back-btn" onClick={() => navigate('/')}>
          Вернуться на главную
        </button>
      </div>
    );
  }

  return (
    <div className="room-container">
      <div className="room-header">
        <div className="room-url-section">
          <input 
            type="text" 
            value={roomUrl} 
            readOnly 
            className="room-url-input"
          />
          <button 
            className="copy-btn" 
            onClick={copyRoomUrl}
            title="Скопировать ссылку"
          >
            {showUrlCopied ? '✓ Скопировано' : '📋 Копировать'}
          </button>
        </div>
      </div>

      <div className="videos-container">
        <div id="remote-videos" className="remote-videos"></div>
        <div className="local-video-wrapper">
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            className="local-video"
          />
          <div className="video-label">Вы</div>
        </div>
      </div>

      <div className="controls">
        <button
          className={`control-btn ${!isVideoEnabled ? 'disabled' : ''}`}
          onClick={toggleVideo}
          title={isVideoEnabled ? 'Выключить видео' : 'Включить видео'}
        >
          {isVideoEnabled ? '📹' : '📹🚫'}
        </button>
        <button
          className={`control-btn ${!isAudioEnabled ? 'disabled' : ''}`}
          onClick={toggleAudio}
          title={isAudioEnabled ? 'Выключить микрофон' : 'Включить микрофон'}
        >
          {isAudioEnabled ? '🎤' : '🎤🚫'}
        </button>
        <button
          className="control-btn leave-btn"
          onClick={leaveRoom}
          title="Покинуть комнату"
        >
          📞 Покинуть
        </button>
      </div>
    </div>
  );
}

export default Room;

