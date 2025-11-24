import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  final picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 🖼 Pick image from gallery
  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  // ☁️ Upload to Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      String fileName = 'items/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      return null;
    }
  }

  // 🧾 Save to Firestore
  Future<void> _saveItem() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select image.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final imageUrl = await _uploadImage(_imageFile!);

      if (imageUrl == null) throw Exception("Image upload failed");

      // Fetch owner name from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final ownerName = userDoc.data()?['name'] ?? 'Unknown';

      await _firestore.collection('items').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'ownerId': _auth.currentUser!.uid,
        'ownerName': ownerName,
        'status': 'Available',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Item added successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Firestore error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Item")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 Image preview box
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: _imageFile == null
                    ? const Center(child: Text("Tap to select image"))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // 🏷 Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Item Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            // 📝 Description input
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            // 💾 Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveItem,
                icon: const Icon(Icons.cloud_upload),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Item"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
