class StreamModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorRole;
  final bool authorIsVerified;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final String category;
  final String duration;
  final int viewsCount;
  int likesCount;
  final int commentsCount;
  final bool isLive;
  final int? viewerCount;
  bool isLiked;
  final String createdAt;

  StreamModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorRole,
    required this.authorIsVerified,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.category,
    required this.duration,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.isLive,
    this.viewerCount,
    this.isLiked = false,
    required this.createdAt,
  });

  factory StreamModel.fromJson(Map<String, dynamic> json) {
    return StreamModel(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Spaces Creator',
      authorAvatar: json['authorAvatar'] ?? '/uploads/admin_avatar.jpg',
      authorRole: json['authorRole'] ?? 'USER',
      authorIsVerified: json['authorIsVerified'] == true,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      category: json['category'] ?? 'trending',
      duration: json['duration'] ?? (json['isLive'] == true ? 'LIVE' : '05:00'),
      viewsCount: json['viewsCount'] ?? 1,
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      isLive: json['isLive'] == true,
      viewerCount: json['viewerCount'],
      isLiked: json['isLiked'] == true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'authorRole': authorRole,
        'authorIsVerified': authorIsVerified,
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'duration': duration,
        'viewsCount': viewsCount,
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'isLive': isLive,
        'viewerCount': viewerCount,
        'isLiked': isLiked,
        'createdAt': createdAt,
      };
}

