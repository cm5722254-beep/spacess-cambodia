import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/stream_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  
  final ValueNotifier<UserModel?> authNotifier = ValueNotifier<UserModel?>(null);
  final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> activeTabIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String?> videoPlaybackOwnerNotifier = ValueNotifier<String?>(null);
  String? _token;
  String? lastErrorMessage;

  void pauseAllVideos({String? exceptId}) {
    videoPlaybackOwnerNotifier.value =
        exceptId ?? 'PAUSE_ALL_${DateTime.now().microsecondsSinceEpoch}';
  }

  UserModel? get currentUser => authNotifier.value;
  bool get isAuthenticated => authNotifier.value != null;

  ApiService._internal() {
    String baseUrl = '/api/v1';
    if (!kIsWeb) {
      baseUrl = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:3000/api/v1'
          : 'http://localhost:3000/api/v1';
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Accept-Language': 'km',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Initialize persistent user session on app launch
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('spaces_auth_token');
      final savedUserJson = prefs.getString('spaces_current_user');
      final savedDark = prefs.getBool('spaces_dark_mode') ?? false;
      isDarkModeNotifier.value = savedDark;

      if (savedToken != null && savedUserJson != null) {
        _token = savedToken;
        final user = UserModel.fromJson(jsonDecode(savedUserJson));
        authNotifier.value = user;
        debugPrint('[ApiService] Session restored for user: ${user.name} (${user.phone})');
      }
    } catch (e) {
      debugPrint('[ApiService] Error restoring session: $e');
    }
  }

  Future<void> setThemeMode(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('spaces_dark_mode', isDark);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<List<StoryModel>> fetchStories() async {
    try {
      final response = await _dio.get('/stories');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((s) => StoryModel.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching stories: $e');
    }
    return [];
  }

  Future<List<StoryModel>> fetchStoryArchive() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return [];
      final response = await _dio.get(
        '/stories/archive',
        queryParameters: {'userId': userId},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((s) => StoryModel.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching story archive: $e');
    }
    return [];
  }

  Future<bool> deleteStory(String storyId) async {
    try {
      final userId = currentUser?.id ?? '';
      final response = await _dio.delete(
        '/stories/$storyId',
        queryParameters: {'userId': userId},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting story: $e');
    }
    return false;
  }

  Future<List<PostModel>> fetchFeed({
    String? spaceId,
    bool isDigest = false,
    String? city,
    String? authorId,
    String? savedByUserId,
  }) async {
    try {
      final response = await _dio.get(
        '/feed',
        queryParameters: {
          if (spaceId != null && spaceId != 'all') 'spaceId': spaceId,
          if (city != null && city.isNotEmpty) 'city': city,
          if (authorId != null && authorId.isNotEmpty) 'authorId': authorId,
          if (savedByUserId != null && savedByUserId.isNotEmpty) 'savedByUserId': savedByUserId,
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
          if (isDigest) 'digest': 'true',
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List rawPosts = response.data['data']['posts'] ?? [];
        return rawPosts.map((p) => PostModel.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching feed: $e');
    }
    return [];
  }

  Future<List<PostModel>> fetchMyPosts() async {
    if (currentUser == null) return [];
    return fetchFeed(authorId: currentUser!.id);
  }

  Future<List<PostModel>> fetchSavedPosts() async {
    if (currentUser == null) return [];
    return fetchFeed(savedByUserId: currentUser!.id);
  }

  Future<List<SpaceModel>> fetchSpaces() async {
    try {
      final response = await _dio.get('/spaces');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List rawSpaces = response.data['data'] ?? [];
        return rawSpaces.map((s) => SpaceModel.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching spaces: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> toggleReaction(String postId, String reaction) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/react',
        data: {
          'reaction': reaction,
          'userId': currentUser?.id ?? 'admin-1',
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] ?? {};
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
    return {};
  }

  Future<CommentItem?> addComment(String postId, String text, {String? parentId}) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/comment',
        data: {
          'text': text,
          'authorId': currentUser?.id ?? '',
          if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final rawComment = (data is Map && data['comment'] != null) ? data['comment'] : data;
        if (rawComment != null && rawComment is Map<String, dynamic>) {
          return CommentItem.fromJson(rawComment);
        }
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
    return null;
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final response = await _dio.delete(
        '/posts/$postId/comments/$commentId',
        queryParameters: {'userId': currentUser?.id ?? ''},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  Future<PostModel?> createPost({
    required String content,
    required String spaceId,
    String? city,
    String? circleName,
    String? imageUrl,
    List<String>? tags,
    String? templateStyle,
    String? moodTag,
  }) async {
    try {
      final response = await _dio.post(
        '/posts',
        data: {
          'content': content,
          'spaceId': spaceId,
          'authorId': currentUser?.id ?? '',
          if (city != null) 'city': city,
          if (circleName != null) 'circleName': circleName,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (tags != null) 'tags': tags,
          if (templateStyle != null && templateStyle.isNotEmpty) 'templateStyle': templateStyle,
          if (moodTag != null && moodTag.isNotEmpty) 'moodTag': moodTag,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return PostModel.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
    }
    return null;
  }

  Future<bool> updatePost(
    String postId, {
    required String content,
    String? city,
    String? imageUrl,
  }) async {
    try {
      final response = await _dio.patch(
        '/posts/$postId',
        data: {
          'userId': currentUser?.id ?? 'admin-1',
          'content': content,
          if (city != null) 'city': city,
          if (imageUrl != null) 'imageUrl': imageUrl,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error updating post: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      final response = await _dio.delete(
        '/posts/$postId',
        queryParameters: {'userId': currentUser?.id ?? ''},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  Future<bool> toggleBookmark(String postId) async {
    try {
      final response = await _dio.post(
        '/posts/$postId/save',
        data: {'userId': currentUser?.id ?? 'admin-1'},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['isSaved'] ?? false;
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
    return false;
  }

  Future<List<ChatConversationModel>> fetchChats() async {
    try {
      final response = await _dio.get(
        '/chats',
        queryParameters: {'userId': currentUser?.id ?? ''},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((c) => ChatConversationModel.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching chats: $e');
    }
    return [];
  }

  Future<ChatConversationModel?> getOrCreateDirectChat(String targetUserId) async {
    try {
      final myId = currentUser?.id;
      if (myId == null || myId.isEmpty) return null;
      final response = await _dio.post(
        '/chats/direct',
        data: {
          'userId1': myId,
          'userId2': targetUserId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = response.data['data'] ?? response.data;
        if (payload is Map<String, dynamic>) {
          return ChatConversationModel.fromJson(payload);
        }
      }
    } catch (e) {
      debugPrint('Error creating direct chat: $e');
    }
    return null;
  }

  Future<List<ChatMessageModel>> fetchMessages(String chatId) async {
    try {
      final response = await _dio.get(
        '/chats/$chatId/messages',
        queryParameters: {
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((m) => ChatMessageModel.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
    return [];
  }

  Future<ChatMessageModel?> sendMessage(
    String chatId,
    String text, {
    String? mediaUrl,
    String mediaType = 'text',
    int? durationSec,
  }) async {
    try {
      final response = await _dio.post(
        '/chats/$chatId/messages',
        data: {
          'text': text,
          'senderId': currentUser?.id ?? 'admin-1',
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          if (durationSec != null) 'durationSec': durationSec,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        return ChatMessageModel.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
    return null;
  }

  // --- USER SEARCH & FRIEND SYSTEM (ADD FRIEND / CONFIRM) ---
  Future<List<PublicUserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/auth/search',
        queryParameters: {
          'q': query,
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((u) => PublicUserModel.fromJson(u)).toList();
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
    return [];
  }

  Future<Map<String, List<PublicUserModel>>> fetchFriendsOverview() async {
    final result = {
      'friends': <PublicUserModel>[],
      'incoming': <PublicUserModel>[],
      'outgoing': <PublicUserModel>[],
    };
    try {
      final uid = currentUser?.id;
      if (uid == null || uid.isEmpty) return result;
      final response = await _dio.get('/friends', queryParameters: {'userId': uid});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        final List rawFriends = data['friends'] ?? [];
        final List rawIn = data['incomingRequests'] ?? [];
        final List rawOut = data['outgoingRequests'] ?? [];
        result['friends'] = rawFriends.map((e) {
          final m = PublicUserModel.fromJson(e);
          m.friendStatus = 'ACCEPTED';
          return m;
        }).toList();
        result['incoming'] = rawIn.map((e) {
          final m = PublicUserModel.fromJson(e);
          m.friendStatus = 'PENDING_RECEIVED';
          return m;
        }).toList();
        result['outgoing'] = rawOut.map((e) {
          final m = PublicUserModel.fromJson(e);
          m.friendStatus = 'PENDING_SENT';
          return m;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    }
    return result;
  }

  Future<bool> sendFriendRequest(String receiverId) async {
    try {
      final uid = currentUser?.id;
      if (uid == null || uid.isEmpty) return false;
      final response = await _dio.post(
        '/friends/request',
        data: {'requesterId': uid, 'receiverId': receiverId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  Future<bool> respondFriendRequest(String requestId, bool accept) async {
    try {
      final uid = currentUser?.id;
      if (uid == null || uid.isEmpty) return false;
      final response = await _dio.post(
        '/friends/respond',
        data: {'requestId': requestId, 'userId': uid, 'accept': accept},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error responding friend request: $e');
      return false;
    }
  }

  Future<bool> removeFriend(String targetUserId) async {
    try {
      final uid = currentUser?.id;
      if (uid == null || uid.isEmpty) return false;
      final response = await _dio.post(
        '/friends/remove',
        data: {'userId1': uid, 'userId2': targetUserId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  Future<void> saveFcmToken(String fcmToken) async {
    try {
      final uid = currentUser?.id;
      if (uid == null || uid.isEmpty || fcmToken.isEmpty) return;
      await _dio.post(
        '/auth/fcm-token',
        data: {'userId': uid, 'fcmToken': fcmToken},
      );
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((n) => NotificationModel.fromJson(n)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  Future<bool> markNotificationRead(String id) async {
    try {
      final response = await _dio.patch('/notifications/$id/read');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchPublicProfile(String usernameOrId) async {
    try {
      final response = await _dio.get(
        '/auth/users/$usernameOrId',
        queryParameters: {
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['data'] is Map) {
          return Map<String, dynamic>.from(response.data['data'] as Map);
        }
      }
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
    }
    return null;
  }

  Future<Author?> fetchUserProfile(String username) async {
    try {
      final response = await _dio.get(
        '/auth/users/$username',
        queryParameters: {
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['data'] != null) {
          return Author.fromJson(response.data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }

  UserModel? _extractUser(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      if (raw['user'] is Map<String, dynamic>) {
        return UserModel.fromJson(raw['user'] as Map<String, dynamic>);
      }
      if (raw['data'] != null) {
        final nested = _extractUser(raw['data']);
        if (nested != null) return nested;
      }
      if (raw['id'] != null && raw['phone'] != null) {
        return UserModel.fromJson(raw);
      }
    }
    return null;
  }

  Future<UserModel?> updateProfile({
    String? name,
    String? bio,
    String? location,
    String? avatar,
    String? email,
  }) async {
    lastErrorMessage = null;
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;
      final response = await _dio.patch(
        '/auth/profile',
        data: {
          'userId': userId,
          if (name != null) 'name': name,
          if (bio != null) 'bio': bio,
          if (location != null) 'location': location,
          if (avatar != null) 'avatar': avatar,
          if (email != null) 'email': email,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedUser = _extractUser(response.data);
        if (updatedUser != null) {
          authNotifier.value = updatedUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('spaces_current_user', jsonEncode(updatedUser.toJson()));
          return updatedUser;
        }
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        lastErrorMessage = data['message'].toString();
      }
      debugPrint('Error updating profile: $e');
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
    return null;
  }

  Future<bool?> toggleFollow(String username) async {
    try {
      final response = await _dio.post(
        '/auth/users/$username/follow',
        data: {'followerId': currentUser?.id ?? 'admin-1'},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] ?? response.data;
        if (data is Map) {
          return data['isFollowing'] as bool?;
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> search(String query) async {
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'q': query,
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final rawPosts = (response.data['data']['posts'] as List? ?? [])
            .map((p) => PostModel.fromJson(p))
            .toList();
        final rawSpaces = (response.data['data']['spaces'] as List? ?? [])
            .map((s) => SpaceModel.fromJson(s))
            .toList();
        return {'posts': rawPosts, 'spaces': rawSpaces};
      }
    } catch (e) {
      debugPrint('Error searching: $e');
    }
    return {'posts': <PostModel>[], 'spaces': <SpaceModel>[]};
  }

  Future<Map<String, dynamic>> updateSettings({bool? hideMetrics, bool? focusMode}) async {
    try {
      final response = await _dio.patch(
        '/users/me/settings',
        data: {
          if (hideMetrics != null) 'hideMetrics': hideMetrics,
          if (focusMode != null) 'focusMode': focusMode,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] ?? {};
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
    return {};
  }

  String _extractAuthError(dynamic error, String fallback) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return 'ម៉ាស៊ីនបម្រើ (Server) កំពុងមមាញឹក ឬមិនទាន់ឆ្លើយតប សូមព្យាយាមម្តងទៀតបន្តិចក្រោយ';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'ការតភ្ជាប់ផុតកំណត់ (Connection Timeout) សូមពិនិត្យមើលអ៊ីនធឺណិត';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'មិនអាចតភ្ជាប់ទៅកាន់ Server បានទេ សូមពិនិត្យមើលប្រព័ន្ធអ៊ីនធឺណិត';
      }
      dynamic data = error.response?.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map) {
        if (data['message'] != null) {
          final m = data['message'];
          if (m is List && m.isNotEmpty) return m.join(', ');
          final str = m.toString();
          if (str.isNotEmpty && str != 'Bad Request') return str;
        }
        if (data['error'] is Map && data['error']['message'] != null) {
          final m = data['error']['message'];
          if (m is List && m.isNotEmpty) return m.join(', ');
          final str = m.toString();
          if (str.isNotEmpty && str != 'Bad Request') return str;
        }
        if (data['error'] is Map && data['error']['localizedMessage'] != null) {
          final str = data['error']['localizedMessage'].toString();
          if (str.isNotEmpty) return str;
        }
        if (data['error'] is String && (data['error'] as String).isNotEmpty) {
          final str = data['error'] as String;
          if (str != 'Bad Request') return str;
        }
      }
      return fallback;
    }
    dynamic errData = error;
    if (errData is String) {
      try {
        errData = jsonDecode(errData);
      } catch (_) {}
    }
    if (errData is Map) {
      if (errData['message'] != null) {
        final m = errData['message'];
        if (m is List && m.isNotEmpty) return m.join(', ');
        return m.toString();
      }
      if (errData['error'] is Map && errData['error']['message'] != null) {
        return errData['error']['message'].toString();
      }
    }
    return fallback;
  }

  // --- AUTHENTICATION & ADMIN API ---

  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        _token = data['token'];
        final user = UserModel.fromJson(data['user']);
        authNotifier.value = user;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('spaces_auth_token', _token!);
        await prefs.setString('spaces_current_user', jsonEncode(user.toJson()));

        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': _extractAuthError(response.data, 'លេខទូរស័ព្ទ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ')};
    } on DioException catch (e) {
      return {'success': false, 'message': _extractAuthError(e, 'លេខទូរស័ព្ទ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ')};
    } catch (e) {
      return {'success': false, 'message': _extractAuthError(e, 'មានបញ្ហាបច្ចេកទេសក្នុងការចូលគណនី')};
    }
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'phone': phone,
          'name': name,
          'username': username,
          'password': password,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        _token = data['token'];
        final user = UserModel.fromJson(data['user']);
        authNotifier.value = user;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('spaces_auth_token', _token!);
        await prefs.setString('spaces_current_user', jsonEncode(user.toJson()));

        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': _extractAuthError(response.data, 'បរាជ័យក្នុងការចុះឈ្មោះ')};
    } on DioException catch (e) {
      return {'success': false, 'message': _extractAuthError(e, 'បរាជ័យក្នុងការចុះឈ្មោះ')};
    } catch (e) {
      return {'success': false, 'message': _extractAuthError(e, 'មានបញ្ហាបច្ចេកទេសក្នុងការចុះឈ្មោះ')};
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    String? email,
    String? name,
    String? avatar,
    String? googleId,
    String? idToken,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          if (email != null) 'email': email,
          if (name != null) 'name': name,
          if (avatar != null) 'avatar': avatar,
          if (googleId != null) 'googleId': googleId,
          if (idToken != null) 'idToken': idToken,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        _token = data['token'];
        final user = _extractUser(data) ?? UserModel.fromJson(data['user']);
        authNotifier.value = user;

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('spaces_auth_token', _token!);
        await prefs.setString('spaces_current_user', jsonEncode(user.toJson()));

        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': _extractAuthError(response.data, 'Google sign-in failed')};
    } catch (e) {
      return {'success': false, 'message': _extractAuthError(e, 'បរាជ័យក្នុងការចូលតាម Google')};
    }
  }

  Future<void> logout() async {
    _token = null;
    authNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('spaces_auth_token');
      await prefs.remove('spaces_current_user');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<List<UserModel>> fetchAdminUsers() async {
    try {
      final response = await _dio.get('/auth/admin/users');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((u) => UserModel.fromJson(u)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
    }
    return [];
  }

  Future<bool> toggleBanUser(String userId) async {
    try {
      final response = await _dio.patch('/auth/admin/users/$userId/ban');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error toggling ban: $e');
      return false;
    }
  }

  Future<AdminStats?> fetchAdminStats() async {
    try {
      final response = await _dio.get('/auth/admin/stats');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return AdminStats.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
    }
    return null;
  }

  // --- MARKETPLACE & E-COMMERCE API ---

  Future<List<ProductModel>> fetchProducts({String? category, String? query, String? city}) async {
    try {
      final response = await _dio.get(
        '/marketplace/products',
        queryParameters: {
          if (category != null && category != 'all') 'category': category,
          if (query != null && query.isNotEmpty) 'q': query,
          if (city != null && city.isNotEmpty) 'city': city,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((p) => ProductModel.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
    return [];
  }

  Future<ProductModel?> createProduct({
    required String title,
    required double priceUsd,
    required String category,
    required String description,
    String? condition,
    String? imageUrl,
    String? location,
    String? sellerBakongId,
    String? sellerStoreName,
  }) async {
    try {
      final user = currentUser;
      final response = await _dio.post(
        '/marketplace/products',
        data: {
          'title': title,
          'priceUsd': priceUsd,
          'category': category,
          'description': description,
          if (condition != null) 'condition': condition,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (location != null) 'location': location,
          if (sellerBakongId != null && sellerBakongId.isNotEmpty) 'sellerBakongId': sellerBakongId,
          if (sellerStoreName != null && sellerStoreName.isNotEmpty) 'sellerStoreName': sellerStoreName,
          'sellerId': user?.id ?? 'admin-1',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (user != null && ((sellerBakongId != null && sellerBakongId.isNotEmpty) || (sellerStoreName != null && sellerStoreName.isNotEmpty))) {
          final updated = UserModel(
            id: user.id,
            phone: user.phone,
            name: user.name,
            username: user.username,
            email: user.email,
            avatar: user.avatar,
            bannerUrl: user.bannerUrl,
            bio: user.bio,
            location: user.location,
            storeName: (sellerStoreName != null && sellerStoreName.isNotEmpty) ? sellerStoreName : user.storeName,
            storePhone: user.storePhone,
            storeDescription: user.storeDescription,
            bakongAccountId: (sellerBakongId != null && sellerBakongId.isNotEmpty) ? sellerBakongId : user.bakongAccountId,
            twoFactorEnabled: user.twoFactorEnabled,
            subscriptionTier: user.subscriptionTier,
            subscriptionExpiresAt: user.subscriptionExpiresAt,
            role: user.role,
            isVerified: user.isVerified,
            isBanned: user.isBanned,
            createdAt: user.createdAt,
          );
          authNotifier.value = updated;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('spaces_current_user', jsonEncode(updated.toJson()));
        }
        return ProductModel.fromJson(response.data['data'] ?? response.data);
      }
    } catch (e) {
      debugPrint('Error creating product: $e');
    }
    return null;
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      final response = await _dio.delete(
        '/marketplace/products/$productId',
        queryParameters: {'userId': currentUser?.id ?? ''},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  // --- STORY API ---
  Future<bool> createStory({required String imageUrl, String? caption}) async {
    try {
      final response = await _dio.post(
        '/stories',
        data: {
          'authorId': currentUser?.id ?? '',
          'imageUrl': imageUrl,
          'caption': caption,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating story: $e');
      return false;
    }
  }

  // --- STORE / MINI SHOP SETTINGS ---
  Future<UserModel?> updateStore({
    required String storeName,
    required String storePhone,
    String? storeDescription,
    String? storeBannerUrl,
    String? storeThemeColor,
    String? storeTagline,
    required String bakongAccountId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return null;
      final response = await _dio.patch(
        '/auth/store',
        data: {
          'userId': user.id,
          'storeName': storeName,
          'storePhone': storePhone,
          if (storeDescription != null) 'storeDescription': storeDescription,
          if (storeBannerUrl != null) 'storeBannerUrl': storeBannerUrl,
          if (storeThemeColor != null) 'storeThemeColor': storeThemeColor,
          if (storeTagline != null) 'storeTagline': storeTagline,
          'bakongAccountId': bakongAccountId,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedUser = _extractUser(response.data);
        if (updatedUser != null) {
          authNotifier.value = updatedUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('spaces_current_user', jsonEncode(updatedUser.toJson()));
          return updatedUser;
        }
      }
    } catch (e) {
      debugPrint('Error updating store: $e');
    }
    return null;
  }

  // --- BAKONG CHECKOUT & PAYMENT SETTLEMENT ---
  Future<Map<String, dynamic>?> checkoutProduct({
    required String productId,
    String currency = 'USD',
  }) async {
    try {
      final response = await _dio.post(
        '/marketplace/checkout',
        data: {
          'productId': productId,
          'buyerId': currentUser?.id ?? 'guest',
          'currency': currency,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data['data'] ?? response.data);
      }
    } catch (e) {
      debugPrint('Error initiating checkout: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkOrderStatus(String md5) async {
    try {
      final response = await _dio.get('/marketplace/orders/$md5/status');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint('Error checking order status: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchUserOrders() async {
    try {
      final user = currentUser;
      if (user == null) return {'purchases': [], 'sales': []};
      final response = await _dio.get('/marketplace/orders/user/${user.id}');
      if (response.statusCode == 200) {
        final raw = response.data['data'] ?? response.data;
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user orders: $e');
    }
    return {'purchases': [], 'sales': []};
  }

  // --- PASSWORD & PRIVACY ---
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      final response = await _dio.post(
        '/auth/change-password',
        data: {
          'userId': user.id,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  Future<UserModel?> updateBanner(String bannerUrl) async {
    try {
      final user = currentUser;
      if (user == null) return null;
      final response = await _dio.patch(
        '/auth/banner',
        data: {
          'userId': user.id,
          'bannerUrl': bannerUrl,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final updated = _extractUser(response.data);
        if (updated != null) {
          authNotifier.value = updated;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('spaces_current_user', jsonEncode(updated.toJson()));
          return updated;
        }
      }
    } catch (e) {
      debugPrint('Error updating banner: $e');
    }
    return null;
  }

  Future<bool> toggleTwoFactor() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      final response = await _dio.patch(
        '/auth/2fa',
        data: {'userId': user.id},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final enabled = response.data['twoFactorEnabled'] ?? false;
        final updated = UserModel(
          id: user.id,
          phone: user.phone,
          name: user.name,
          username: user.username,
          avatar: user.avatar,
          bannerUrl: user.bannerUrl,
          bio: user.bio,
          location: user.location,
          storeName: user.storeName,
          storePhone: user.storePhone,
          storeDescription: user.storeDescription,
          bakongAccountId: user.bakongAccountId,
          twoFactorEnabled: enabled,
          subscriptionTier: user.subscriptionTier,
          subscriptionExpiresAt: user.subscriptionExpiresAt,
          role: user.role,
        );
        authNotifier.value = updated;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('spaces_current_user', jsonEncode(updated.toJson()));
        return enabled;
      }
    } catch (e) {
      debugPrint('Error toggling 2FA: $e');
    }
    return false;
  }

  Future<UserModel?> subscribeTier(String tier, int durationMonths) async {
    try {
      final user = currentUser;
      if (user == null) return null;
      final response = await _dio.post(
        '/auth/subscribe',
        data: {
          'userId': user.id,
          'tier': tier,
          'durationMonths': durationMonths,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final updated = _extractUser(response.data);
        if (updated != null) {
          authNotifier.value = updated;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('spaces_current_user', jsonEncode(updated.toJson()));
          return updated;
        }
      }
    } catch (e) {
      debugPrint('Error subscribing tier: $e');
    }
    return null;
  }

  /// Uploads binary data (decoded from dataUrl) via multipart /storage/upload-file directly to R2
  Future<String?> uploadVoiceDataUrl(String dataUrl) async {
    try {
      final commaIdx = dataUrl.indexOf(',');
      if (commaIdx <= 0) {
        return await uploadMedia(dataUrl, filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm');
      }
      final header = dataUrl.substring(0, commaIdx);
      final base64Part = dataUrl.substring(commaIdx + 1);
      final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(header);
      final rawMime = (mimeMatch?.group(1) ?? 'audio/webm').toLowerCase();
      final ext = rawMime.contains('mp4')
          ? 'm4a'
          : rawMime.contains('ogg')
              ? 'ogg'
              : rawMime.contains('mpeg')
                  ? 'mp3'
                  : 'webm';
      final bytes = base64Decode(base64Part);
      final fname = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final formData = FormData.fromMap({
        'prefix': 'voice',
        'filename': fname,
        'mimeType': rawMime,
        'file': MultipartFile.fromBytes(bytes, filename: fname),
      });
      final response = await _dio.post(
        '/storage/upload-file',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        if (data is Map && data['url'] != null) {
          return data['url'].toString();
        }
      }
    } catch (e) {
      debugPrint('Error uploading voice binary to R2, falling back to base64: $e');
    }
    return await uploadMedia(dataUrl, filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm');
  }

  /// Uploads media directly (base64) to server disk storage and returns the live URL (/uploads/media-...)
  Future<String?> uploadMedia(String base64Data, {String? filename}) async {
    try {
      final response = await _dio.post(
        '/storage/upload',
        data: {
          'base64Data': base64Data,
          if (filename != null) 'filename': filename,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['success'] == true && response.data['data'] != null) {
          return response.data['data']['url'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
    }
    return null;
  }

  /// Real Bakong KHQR Gateway checkout for VIP Blue Checkmark Badge
  Future<Map<String, dynamic>?> checkoutVip({
    required String tier,
    required int durationMonths,
    double? amount,
    String? currency = 'USD',
  }) async {
    try {
      final user = currentUser;
      final userId = user?.id ?? 'admin-1';
      final response = await _dio.post(
        '/auth/vip/checkout',
        data: {
          'userId': userId,
          'tier': tier,
          'durationMonths': durationMonths,
          if (amount != null) 'amount': amount,
          'currency': currency,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['data'] != null) {
          return response.data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error checking out VIP: $e');
    }
    return null;
  }

  /// Check VIP payment status by MD5 directly on live NBC Ledger.
  /// When paid, instantly unlocks Verified Blue Badge and VIP tier.
  Future<Map<String, dynamic>?> checkVipStatus(String md5) async {
    try {
      final response = await _dio.get('/auth/vip/status/$md5');
      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          if (data['paid'] == true && data['user'] != null) {
            final updatedUser = UserModel.fromJson(data['user']);
            authNotifier.value = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('spaces_current_user', jsonEncode(updatedUser.toJson()));
          }
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error checking VIP status: $e');
    }
    return null;
  }

  // --- REELS (TIKTOK / FACEBOOK VIDEO FEED) ---
  Future<List<PostModel>> fetchReels() async {
    try {
      final response = await _dio.get(
        '/reels',
        queryParameters: {'currentUserId': currentUser?.id ?? 'admin-1'},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((r) => PostModel.fromJson(r)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching reels: $e');
    }
    return [];
  }

  Future<PostModel?> createReel({
    required String videoUrl,
    String? content,
    String? audioTitle,
    String? location,
    String? spaceId,
    List<String>? tags,
    bool isBoosted = false,
    bool isAiGenerated = false,
    bool shareToStory = false,
  }) async {
    try {
      final user = currentUser;
      final response = await _dio.post(
        '/reels',
        data: {
          'authorId': user?.id,
          'videoUrl': videoUrl,
          'content': content ?? '',
          'audioTitle': audioTitle ?? 'Original Audio - Spaces Cambodia',
          'location': location,
          if (spaceId != null && spaceId.isNotEmpty) 'spaceId': spaceId,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
          'isBoosted': isBoosted,
          'isAiGenerated': isAiGenerated,
          'shareToStory': shareToStory,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PostModel.fromJson(response.data['data'] ?? response.data);
      }
    } catch (e) {
      debugPrint('Error creating reel: $e');
    }
    return null;
  }

  // --- STREAMS & VIDEO WATCH (YOUTUBE / FACEBOOK WATCH) ---
  Future<List<StreamModel>> fetchStreams({String? category, String? authorId}) async {
    try {
      final response = await _dio.get(
        '/streams',
        queryParameters: {
          if (category != null && category != 'all') 'category': category,
          if (authorId != null && authorId.isNotEmpty) 'authorId': authorId,
          if (currentUser?.id != null) 'currentUserId': currentUser!.id,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        return raw.map((s) => StreamModel.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching streams: $e');
    }
    return [];
  }

  Future<StreamModel?> createStream({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    String? category,
    String? duration,
    bool isLive = false,
    String? liveTheme,
    String? pinnedNotice,
    String? videoFilter,
  }) async {
    try {
      final user = currentUser;
      final response = await _dio.post(
        '/streams',
        data: {
          'authorId': user?.id ?? 'admin-1',
          'title': title,
          'description': description,
          'videoUrl': videoUrl,
          if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
          'category': category ?? 'trending',
          'duration': duration ?? (isLive ? 'LIVE' : '05:00'),
          'isLive': isLive,
          if (liveTheme != null) 'liveTheme': liveTheme,
          if (pinnedNotice != null) 'pinnedNotice': pinnedNotice,
          if (videoFilter != null) 'videoFilter': videoFilter,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return StreamModel.fromJson(response.data['data'] ?? response.data);
      }
    } catch (e) {
      debugPrint('Error creating stream: $e');
    }
    return null;
  }

  Future<StreamModel?> customizeStream(
    String streamId, {
    String? liveTheme,
    String? pinnedNotice,
    String? videoFilter,
  }) async {
    try {
      final response = await _dio.patch(
        '/streams/$streamId/customize',
        data: {
          'userId': currentUser?.id ?? '',
          if (liveTheme != null) 'liveTheme': liveTheme,
          if (pinnedNotice != null) 'pinnedNotice': pinnedNotice,
          if (videoFilter != null) 'videoFilter': videoFilter,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final raw = response.data['data']?['stream'] ?? response.data['stream'] ?? response.data['data'];
        if (raw is Map<String, dynamic>) {
          return StreamModel.fromJson(raw);
        }
      }
    } catch (e) {
      debugPrint('Error customizing stream: $e');
    }
    return null;
  }

  Future<bool> toggleStreamLike(String streamId) async {
    try {
      final user = currentUser;
      final response = await _dio.post(
        '/streams/$streamId/like',
        data: {'userId': user?.id ?? 'admin-1'},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']?['isLiked'] ?? true;
      }
    } catch (e) {
      debugPrint('Error toggling stream like: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchLiveStreamState(String streamId) async {
    try {
      final viewerId = currentUser?.id ?? 'guest-viewer';
      final response = await _dio.get(
        '/streams/$streamId/live-state',
        queryParameters: {'viewerId': viewerId},
      );
      if (response.statusCode == 200) {
        final raw = response.data['data'] ?? response.data;
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    } catch (e) {
      debugPrint('Error fetching live state: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchStreamComments(String streamId) async {
    try {
      final response = await _dio.get('/streams/$streamId/comments');
      if (response.statusCode == 200) {
        final raw = response.data['data'] ?? response.data;
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching stream comments: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> addStreamComment(
    String streamId,
    String text, {
    String? parentId,
  }) async {
    try {
      final user = currentUser;
      final response = await _dio.post(
        '/streams/$streamId/comments',
        data: {
          'authorId': user?.id ?? 'admin-1',
          'text': text,
          if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data['data'] ?? response.data;
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    } catch (e) {
      debugPrint('Error posting stream comment: $e');
    }
    return null;
  }

  Future<bool> deleteStream(String streamId) async {
    try {
      final userId = currentUser?.id ?? 'admin-1';
      final response = await _dio.delete(
        '/streams/$streamId',
        queryParameters: {'userId': userId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting stream: $e');
    }
    return false;
  }

  // --- AI ASSISTANT CHAT & SYSTEM TOOL ---
  Future<Map<String, dynamic>?> askAi(String message) async {
    try {
      final response = await _dio.post(
        '/ai/chat',
        data: {'message': message},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error asking AI: $e');
    }
    return null;
  }
}
