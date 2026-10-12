import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';

class StorageService {
  static final SupabaseClient _supabase = SupabaseService.client;
  
  // Upload file
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      await _supabase.storage.from(bucket).upload(path, file);
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }
  
  // Upload image from picker
  static Future<String?> uploadImage({
    required String bucket,
    required String path,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (pickedFile == null) return null;
      
      final file = File(pickedFile.path);
      final extension = pickedFile.path.split('.').last;
      final fileName = '$path.$extension';
      
      return await uploadFile(
        bucket: bucket,
        path: fileName,
        file: file,
      );
    } catch (e) {
      print('Error picking/uploading image: $e');
      return null;
    }
  }
  
  // Upload avatar
  static Future<String?> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final path = 'avatars/$userId/profile.jpg';
    return await uploadFile(
      bucket: 'avatars',
      path: path,
      file: file,
    );
  }
  
  // Upload receipt
  static Future<String?> uploadReceipt({
    required String receiptNumber,
    required File file,
  }) async {
    final path = 'receipts/$receiptNumber.pdf';
    return await uploadFile(
      bucket: 'receipts',
      path: path,
      file: file,
    );
  }
  
  // Delete file
  static Future<bool> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
  
  // Get public URL
  static String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }
  
  // Download file
  static Future<File?> downloadFile({
    required String bucket,
    required String path,
    required String destinationPath,
  }) async {
    try {
      final response = await _supabase.storage
          .from(bucket)
          .download(path);
      
      final file = File(destinationPath);
      await file.writeAsBytes(response);
      return file;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }
  
  // ✅ List files - الحل الصحيح
  static Future<List<String>?> listFiles({
    required String bucket,
    String? prefix,
  }) async {
    try {
      // ✅ استخدم path: كـ named parameter
      final response = await _supabase.storage.from(bucket).list(
        path: prefix ?? '',
      );
      
      return response.map((item) => item.name).toList();
    } catch (e) {
      print('Error listing files: $e');
      return null;
    }
  }
}