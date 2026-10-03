import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../services/image_service.dart';
import '../../widgets/custom_button.dart';

/// Screen allowing users to update their profile details (Name, City, Photo, Role).
/// Mobile number is verified and protected from casual editing.
class EditProfileScreen extends StatefulWidget {
  final AuthController? authController;

  const EditProfileScreen({
    super.key,
    this.authController,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AuthController _authController;
  final ImageService _imageService = ImageService();

  late final TextEditingController _nameController;
  late final TextEditingController _cityController;

  String _selectedRole = 'collector';
  String? _photoPath;
  String? _nameError;
  String? _cityError;
  bool _isLoading = false;

  final List<String> _suggestedCities = const [
    'Pune',
    'Mumbai',
    'Nashik',
    'Nagpur',
    'Thane',
    'Aurangabad',
  ];

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
    final user = _authController.currentUser ?? UserProfile.defaultCollector();

    _nameController = TextEditingController(text: user.name);
    _cityController = TextEditingController(text: user.city);
    _selectedRole = user.role;
    _photoPath = user.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSourceType source) async {
    try {
      final result = source == ImageSourceType.camera
          ? await _imageService.captureFromCamera()
          : await _imageService.pickFromGallery();

      if (result != null) {
        final savedPath = await ImageService.saveImageToAppStorage(result.xFile);
        if (mounted) {
          setState(() {
            _photoPath = savedPath ?? result.filePath;
          });
        }
      }
    } catch (_) {}
  }

  void _showPhotoOptions() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 28),
                  title: Text(loc.translate('takeCameraPhoto'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSourceType.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary, size: 28),
                  title: Text(loc.translate('chooseFromGallery'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSourceType.gallery);
                  },
                ),
                if (_photoPath != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                    title: Text(loc.translate('removePhoto'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _photoPath = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSaveChanges() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    bool hasError = false;
    if (name.isEmpty) {
      setState(() {
        _nameError = loc.translate('nameRequiredError');
      });
      hasError = true;
    } else {
      setState(() {
        _nameError = null;
      });
    }

    if (city.isEmpty) {
      setState(() {
        _cityError = loc.translate('cityRequiredError');
      });
      hasError = true;
    } else {
      setState(() {
        _cityError = null;
      });
    }

    if (hasError) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authController.currentUser ?? UserProfile.defaultCollector();
      final updated = currentUser.copyWith(
        name: name,
        city: city,
        role: _selectedRole,
        photoPath: _photoPath,
      );

      await _authController.updateProfile(updated);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('profileUpdated')),
          backgroundColor: AppColors.syncSuccess,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = _authController.currentUser ?? UserProfile.defaultCollector();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(loc.translate('editProfile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: (_photoPath != null && !kIsWeb && File(_photoPath!).existsSync())
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: (_photoPath == null || (kIsWeb && _photoPath != null) || (!kIsWeb && !File(_photoPath!).existsSync()))
                          ? const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showPhotoOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _showPhotoOptions,
                  child: Text(
                    _photoPath == null ? loc.translate('addPhoto') : loc.translate('changePhoto'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Full Name TextField
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('fullName'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Text(' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: loc.translate('enterFullName'),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) {
                          if (_nameError != null) {
                            setState(() {
                              _nameError = null;
                            });
                          }
                        },
                      ),
                      if (_nameError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _nameError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Verified Mobile Number (Read-only with badge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.syncSuccess, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('verifiedMobile'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.formattedPhone,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.lock_rounded, color: Colors.grey, size: 18),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.translate('cannotEditPhone'),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Area / City TextField & Quick Chips
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('cityArea'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Text(' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cityController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: loc.translate('enterCityArea'),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) {
                          if (_cityError != null) {
                            setState(() {
                              _cityError = null;
                            });
                          }
                        },
                      ),
                      if (_cityError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _cityError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _suggestedCities.map((city) {
                          final isSel = _cityController.text.trim().toLowerCase() == city.toLowerCase();
                          return ActionChip(
                            label: Text(city),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? Colors.white : AppColors.textPrimary,
                            ),
                            backgroundColor: isSel ? AppColors.primary : AppColors.background,
                            onPressed: () {
                              setState(() {
                                _cityController.text = city;
                                _cityError = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Role Selector
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.work_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('whatDoYouDo'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedRole = 'collector'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _selectedRole == 'collector'
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedRole == 'collector' ? AppColors.primary : Colors.black12,
                                    width: _selectedRole == 'collector' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text('🛒', style: TextStyle(fontSize: 24)),
                                    const SizedBox(height: 6),
                                    Text(
                                      loc.translate('scrapCollector'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedRole == 'collector' ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedRole = 'recycler'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _selectedRole == 'recycler'
                                      ? AppColors.secondary.withValues(alpha: 0.12)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedRole == 'recycler' ? AppColors.secondary : Colors.black12,
                                    width: _selectedRole == 'recycler' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text('♻️', style: TextStyle(fontSize: 24)),
                                    const SizedBox(height: 6),
                                    Text(
                                      loc.translate('recyclerRole'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedRole == 'recycler' ? AppColors.secondary : AppColors.textPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Save CTA
              CustomButton(
                label: loc.translate('saveChanges'),
                icon: Icons.check_circle_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleSaveChanges,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

enum ImageSourceType { camera, gallery }
