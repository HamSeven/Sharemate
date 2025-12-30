import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'theme/design_tokens.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _image;
  bool _loading = false;

  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final ref = _storage
          .ref('items/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty ||
        _descCtrl.text.isEmpty ||
        _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = _auth.currentUser!.uid;
      final imageUrl = await _uploadImage(_image!);
      if (imageUrl == null) throw "Upload failed";

      final userDoc =
          await _firestore.collection('users').doc(uid).get();

      await _firestore.collection('items').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'imageUrl': imageUrl,
        'ownerId': uid,
        'ownerName': userDoc['name'],
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Add New Item"),
        backgroundColor: AppColors.card,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================
              // Image
              // =====================
              Text("Item Image", style: AppText.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _image == null
                      ? const Center(
                          child: Icon(Icons.add_a_photo,
                              color: AppColors.textSecondary),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // =====================
              // Title
              // =====================
              Text("Title", style: AppText.titleMedium),
              const SizedBox(height: 6),
              _field(
                controller: _titleCtrl,
                hint: "Item title",
              ),

              const SizedBox(height: 12),

              // =====================
              // Description
              // =====================
              Text("Description", style: AppText.titleMedium),
              const SizedBox(height: 6),
              _field(
                controller: _descCtrl,
                hint: "Describe the item",
                maxLines: 4,
              ),

              const SizedBox(height: 20),

              // =====================
              // Submit Button
              // =====================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: AppButtons.primary,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Add Item"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================
  // Reusable field
  // =====================
  Widget _field({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
