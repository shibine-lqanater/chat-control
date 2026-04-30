const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

io.on('connection', (socket) => {
    console.log('A user connected:', socket.id);

    socket.on('join', (room) => {
        socket.join(room);
        console.log(`User ${socket.id} joined room: ${room}`);
    });

    socket.on('message', (data) => {
        console.log('Message received:', data);
        // Broadcast to everyone in the room
        io.to(data.room).emit('message', data);
    });

    socket.on('webrtc_signal', (data) => {
        console.log('WebRTC Signal to:', data.targetId);
        // Send directly to the target user or broadcast to room (mesh)
        // For simplicity in Mesh, we can broadcast to the room
        socket.to(data.room).emit('webrtc_signal', data);
    });

    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`Socket.io Server running on port ${PORT}`);
});
