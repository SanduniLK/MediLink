import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/chat_service.dart';
import 'dart:io';

class DoctorChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String patientName;
  final String patientId;
  final String doctorId;
  final String doctorName;

  const DoctorChatScreen({
    super.key,
    required this.chatRoomId,
    required this.patientName,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    
    // Debug to see what's in the database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.debugChatRoom(widget.chatRoomId);
      _chatService.debugAllMessages(widget.chatRoomId);
    });
  }

  void _setupMessageListener() {
    _chatService.getMessages(widget.chatRoomId).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    }, onError: (error) {
      debugPrint('❌ Error in message stream: $error');
    });
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
        senderName: widget.doctorName,
        senderRole: 'doctor',
      );

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

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
        senderId: widget.doctorId,
        senderName: widget.doctorName,
        senderRole: 'doctor',
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
          SnackBar(
            content: Text('Downloading ${message['fileName']}...'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      await _chatService.downloadAndOpenFile(
        message['fileUrl'],
        message['fileName'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File opened successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e. Please check permissions.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessage(_messages[index]);
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
    final isMe = message['senderId'] == widget.doctorId;
    final timestamp = message['timestamp'];
    final time = timestamp != null 
        ? DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(timestamp))
        : '';

    if (message['type'] == 'file') {
      return _buildFileMessage(message, isMe, time);
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) 
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 14, color: Colors.grey[600]),
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
                    message['text'] ?? '',
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
              backgroundColor: Colors.green,
              child: Icon(Icons.medical_services, size: 14, color: Colors.white),
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
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 14, color: Colors.grey[600]),
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              constraints: BoxConstraints(maxWidth: 280),
              child: Card(
                elevation: 2,
                color: isMe ? Color(0xFF18A3B6) : Colors.white,
                child: InkWell(
                  onTap: () => _handleFileTap(message),
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
              backgroundColor: Colors.green,
              child: Icon(Icons.medical_services, size: 14, color: Colors.white),
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
          IconButton(
            icon: Icon(Icons.attach_file, color: Color(0xFF18A3B6)),
            onPressed: _isUploading ? null : _showFilePicker,
            tooltip: 'Attach file',
          ),
          SizedBox(width: 4),
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