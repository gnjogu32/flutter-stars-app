import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadChatMedia(String conversationId, XFile file) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference ref = _storage.ref().child('chats/$conversationId/$fileName');

      final UploadTask uploadTask = ref.putFile(File(file.path));
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadChatVideo(String conversationId, XFile file) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference ref = _storage.ref().child('chats/$conversationId/videos/$fileName');

      final UploadTask uploadTask = ref.putFile(File(file.path));
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
