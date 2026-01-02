import dotenv from 'dotenv';
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Загружаем .env файл из корня проекта
const envPath = path.resolve(__dirname, '../.env');
dotenv.config({ path: envPath });
console.log('Loading .env from:', envPath);
console.log('NODE_ENV:', process.env.NODE_ENV);

const app = express();
const httpServer = createServer(app);

const CLIENT_URL = process.env.CLIENT_URL || (process.env.NODE_ENV === 'production' ? '*' : 'http://localhost:3000');

const io = new Server(httpServer, {
  cors: {
    origin: CLIENT_URL,
    methods: ["GET", "POST"],
    credentials: true
  }
});

app.use(cors({
  origin: CLIENT_URL,
  credentials: true
}));
app.use(express.json());

// Раздача статических файлов в production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../client/build')));
}

// Хранилище комнат
const rooms = new Map();

// Генерация уникальной ссылки для комнаты
app.post('/api/rooms', (req, res) => {
  const roomId = uuidv4();
  rooms.set(roomId, {
    id: roomId,
    participants: [],
    createdAt: new Date()
  });
  res.json({ roomId, url: `/room/${roomId}` });
});

// Проверка существования комнаты
app.get('/api/rooms/:roomId', (req, res) => {
  const { roomId } = req.params;
  if (rooms.has(roomId)) {
    res.json({ exists: true });
  } else {
    res.status(404).json({ exists: false });
  }
});

// Socket.io обработчики
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('join-room', (roomId) => {
    if (!rooms.has(roomId)) {
      socket.emit('error', { message: 'Room does not exist' });
      return;
    }

    socket.join(roomId);
    const room = rooms.get(roomId);
    
    // Получаем список участников ДО добавления текущего пользователя
    const otherParticipants = room.participants.filter(id => id !== socket.id);
    
    // Добавляем текущего пользователя в список участников
    if (!room.participants.includes(socket.id)) {
      room.participants.push(socket.id);
    }

    // Уведомляем других участников о новом подключении
    socket.to(roomId).emit('user-joined', socket.id);

    // Отправляем список существующих участников новому пользователю (без него самого)
    if (otherParticipants.length > 0) {
      socket.emit('existing-users', otherParticipants);
    }

    console.log(`User ${socket.id} joined room ${roomId}`);
  });

  socket.on('offer', (data) => {
    socket.to(data.target).emit('offer', {
      offer: data.offer,
      sender: socket.id
    });
  });

  socket.on('answer', (data) => {
    socket.to(data.target).emit('answer', {
      answer: data.answer,
      sender: socket.id
    });
  });

  socket.on('ice-candidate', (data) => {
    socket.to(data.target).emit('ice-candidate', {
      candidate: data.candidate,
      sender: socket.id
    });
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
    
    // Удаляем пользователя из всех комнат
    rooms.forEach((room, roomId) => {
      if (room.participants.includes(socket.id)) {
        room.participants = room.participants.filter(id => id !== socket.id);
        socket.to(roomId).emit('user-left', socket.id);
        
        // Удаляем комнату если она пустая
        if (room.participants.length === 0) {
          rooms.delete(roomId);
        }
      }
    });
  });
});

// Обработка всех маршрутов для SPA в production
if (process.env.NODE_ENV === 'production') {
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../client/build/index.html'));
  });
}

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';
httpServer.listen(PORT, HOST, () => {
  console.log(`Server running on ${HOST}:${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Client URL: ${process.env.CLIENT_URL || 'not set'}`);
});

