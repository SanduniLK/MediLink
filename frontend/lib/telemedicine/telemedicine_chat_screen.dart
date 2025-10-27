// telemedicine_chat_screen.dart - COMPLETE CORRECTED VERSION FOR PATIENTS
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/chat_service.dart';

class TelemedicineChatScreen extends StatefulWidget {
  final String sessionId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String chatRoomId;

  const TelemedicineChatScreen({
    super.key,
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.chatRoomId,
  });

  @override
  State<TelemedicineChatScreen> createState() => _TelemedicineChatScreenState();
}

class _TelemedicineChatScreenState extends State<TelemedicineChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false; // ADD THIS MISSING VARIABLE

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        message: message,
        senderId: user.uid,
        senderName: widget.patientName,
        senderRole: 'patient',
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  // === FILE SHARING METHODS FOR PATIENT ===
  void _sendFileMessage(File file, String fileName) async {
    if (!mounted) return;
    
    setState(() {
      _isUploading = true;
    });

    try {
      await _chatService.sendFileMessage(
        chatRoomId: widget.chatRoomId,
        file: file,
        fileName: fileName,
        senderId: widget.patientId,
        senderName: widget.patientName,
        senderRole: 'patient',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showFilePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _takePhoto();
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text('Choose Document'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickDocument();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final File? imageFile = await _chatService.pickImage();
      if (imageFile != null && mounted) {
        final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _sendFileMessage(imageFile, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final File? imageFile = await _chatService.pickCameraImage();
      if (imageFile != null && mounted) {
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _sendFileMessage(imageFile, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final File? documentFile = await _chatService.pickDocument();
      if (documentFile != null && mounted) {
        final fileName = documentFile.path.split('/').last;
        _sendFileMessage(documentFile, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }

  void _handleFileTap(Map<String, dynamic> message) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${message['fileName']}...')),
        );
      }

      await _chatService.downloadAndOpenFile(
        message['fileUrl'],
        message['fileName'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorName}'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getMessages(widget.chatRoomId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading messages'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data ?? [];

                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    if (messages.isEmpty) {
                      return Center(child: Text('No messages yet. Start the conversation!'));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessage(messages[index]);
                      },
                    );
                  },
                ),
                if (_isUploading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isMe = message['senderId'] == widget.patientId;
    final time = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
    );

    // Check if message is a file
    if (message['type'] == 'file') {
      return _buildFileMessage(message, isMe, time);
    }

    // Regular text message
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) 
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF18A3B6),
              child: Icon(Icons.medical_services, size: 14, color: Colors.white),
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Color(0xFF18A3B6) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'],
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message, bool isMe, String time) {
    final String fileType = message['fileType'] ?? 'file';
    final String fileName = message['fileName'] ?? 'Unknown file';
    final int fileSize = message['fileSize'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) 
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF18A3B6),
              child: Icon(Icons.medical_services, size: 14, color: Colors.white),
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              constraints: BoxConstraints(maxWidth: 280),
              child: Card(
                elevation: 2,
                color: isMe ? Color(0xFF18A3B6) : Colors.white,
                child: InkWell(
                  onTap: () => _handleFileTap(message), // FIXED: Now this method is used
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFileIcon(fileType),
                        SizedBox(height: 8),
                        Text(
                          fileName,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _chatService.getFileSizeString(fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String fileType) {
    final double iconSize = 32;
    final Color iconColor = Colors.grey[600]!;

    switch (fileType) {
      case 'image':
        return Icon(Icons.image, size: iconSize, color: iconColor);
      case 'pdf':
        return Icon(Icons.picture_as_pdf, size: iconSize, color: iconColor);
      case 'document':
        return Icon(Icons.description, size: iconSize, color: iconColor);
      case 'text':
        return Icon(Icons.text_snippet, size: iconSize, color: iconColor);
      default:
        return Icon(Icons.insert_drive_file, size: iconSize, color: iconColor);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // File picker button - PATIENTS CAN NOW SEND FILES TOO!
          IconButton(
            icon: Icon(Icons.attach_file, color: Color(0xFF18A3B6)),
            onPressed: _isUploading ? null : _showFilePicker, // FIXED: Now this method is used
            tooltip: 'Attach file',
          ),
          SizedBox(width: 4),
          // Message input field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          // Send button
          CircleAvatar(
            backgroundColor: Color(0xFF18A3B6),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}