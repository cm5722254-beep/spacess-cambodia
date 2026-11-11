class Author {
  final String id;
  final String name;
  final String username;
  final String avatar;
  final bool isVerified;
  final String role;
  final String location;
  final String bio;
  int followerCount;
  int followingCount;
  bool isFollowing;

  Author({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
    required this.isVerified,
    required this.role,
    this.location = 'Phnom Penh, Cambodia',
    this.bio = '',
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      avatar: (json['avatar'] != null && json['avatar'].toString().isNotEmpty)
          ? json['avatar'].toString()
          : '/default_avatar.svg',
      isVerified: json['isVerified'] ?? false,
      role: json['role'] ?? '',
      location: json['location'] ?? 'Phnom Penh, Cambodia',
      bio: json['bio'] ?? '',
      followerCount: json['followerCount'] ?? 100,
      followingCount: json['followingCount'] ?? 50,
      isFollowing: json['isFollowing'] ?? false,
    );
  }
}

class SpaceRef {
  final String id;
  final String name;
  final String mode;
  final String color;
  final String icon;

  SpaceRef({
    required this.id,
    required this.name,
    required this.mode,
    required this.color,
    required this.icon,
  });

  factory SpaceRef.fromJson(Map<String, dynamic> json) {
    return SpaceRef(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      mode: json['mode'] ?? 'PUBLIC',
      color: json['color'] ?? '#007AFF',
      icon: json['icon'] ?? 'globe',
    );
  }
}

class CommentItem {
  final String id;
  final String author;
  final String authorId;
  final String avatar;
  final String text;
  final String timeAgo;

  CommentItem({
    required this.id,
    required this.author,
    this.authorId = '',
    required this.avatar,
    required this.text,
    required this.timeAgo,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: json['id'] ?? '',
      author: json['author'] ?? '',
      authorId: json['authorId'] ?? '',
      avatar: json['avatar'] ?? '',
      text: json['text'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
    );
  }
}

class PostModel {
  final String id;
  final Author author;
  final SpaceRef space;
  final String circle;
  final String city;
  final String content;
  final String? imageUrl;
  final double aspectRatio;
  final String timeAgo;
  int likeCount;
  int commentCount;
  int shareCount;
  bool isLiked;
  String selectedReaction; // 'LIKE', 'LOVE', 'CELEBRATE', 'HAHA', 'WOW', 'SAD'
  bool isBookmarked;
  final bool isTimeCapsule;
  final String? unlockAt;
  final bool isExpiring;
  final String? expiresIn;
  final bool isBoosted;
  final bool isReel;
  final String? videoUrl;
  final String? reelAudioTitle;
  final List<String> tags;
  final List<CommentItem> comments;

  PostModel({
    required this.id,
    required this.author,
    required this.space,
    required this.circle,
    required this.city,
    required this.content,
    this.imageUrl,
    this.aspectRatio = 1.5,
    required this.timeAgo,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
    this.selectedReaction = 'LIKE',
    required this.isBookmarked,
    this.isTimeCapsule = false,
    this.unlockAt,
    this.isExpiring = false,
    this.expiresIn,
    this.isBoosted = false,
    this.isReel = false,
    this.videoUrl,
    this.reelAudioTitle,
    required this.tags,
    required this.comments,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      author: Author.fromJson(json['author'] ?? {}),
      space: SpaceRef.fromJson(json['space'] ?? {}),
      circle: json['circle'] ?? 'Public / សាធារណៈ',
      city: json['city'] ?? 'Phnom Penh, Cambodia',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      aspectRatio: (json['aspectRatio'] ?? 1.5).toDouble(),
      timeAgo: json['timeAgo'] ?? 'ទើបតែឥឡូវនេះ',
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      shareCount: json['shareCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      selectedReaction: json['selectedReaction'] ?? 'LIKE',
      isBookmarked: json['isBookmarked'] ?? false,
      isTimeCapsule: json['isTimeCapsule'] ?? false,
      unlockAt: json['unlockAt'],
      isExpiring: json['isExpiring'] ?? false,
      expiresIn: json['expiresIn'],
      isBoosted: json['isBoosted'] ?? false,
      isReel: json['isReel'] ?? false,
      videoUrl: json['videoUrl'],
      reelAudioTitle: json['reelAudioTitle'],
      tags: (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => CommentItem.fromJson(c))
              .toList() ??
          [],
    );
  }
}

class StoryModel {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String city;
  final String imageUrl;
  final String caption;
  final String timeAgo;
  bool isViewed;

  StoryModel({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.city,
    required this.imageUrl,
    required this.caption,
    required this.timeAgo,
    this.isViewed = false,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? '',
      authorName: json['author']?['name'] ?? '',
      authorAvatar: json['author']?['avatar'] ?? '/default_avatar.svg',
      city: json['city'] ?? 'Cambodia',
      imageUrl: json['imageUrl'] ?? json['coverUrl'] ?? '',
      caption: json['caption'] ?? json['title'] ?? '',
      timeAgo: json['timeAgo'] ?? 'ថ្មីៗនេះ',
      isViewed: json['isViewed'] ?? false,
    );
  }
}

class ChatConversationModel {
  final String id;
  final String participantId;
  final String participantUsername;
  final bool isVerified;
  final String title;
  final String avatar;
  final bool isGroup;
  final String? spaceName;
  String lastMessage;
  String lastMessageTime;
  int unreadCount;

  ChatConversationModel({
    required this.id,
    this.participantId = '',
    this.participantUsername = '',
    this.isVerified = false,
    required this.title,
    required this.avatar,
    required this.isGroup,
    this.spaceName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      id: json['id'] ?? '',
      participantId: json['participantId'] ?? '',
      participantUsername: json['participantUsername'] ?? '',
      isVerified: json['isVerified'] == true,
      title: json['title'] ?? json['participantName'] ?? 'ការជជែក',
      avatar: json['avatar'] ?? json['participantAvatar'] ?? '/default_avatar.svg',
      isGroup: json['isGroup'] ?? false,
      spaceName: json['spaceName'],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] ?? json['timeAgo'] ?? '',
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String? mediaUrl;
  final String mediaType; // 'text', 'image', 'video', 'voice'
  final int durationSec;
  final String timeAgo;
  final bool isMe;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    this.senderId = '',
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    this.mediaUrl,
    this.mediaType = 'text',
    this.durationSec = 0,
    required this.timeAgo,
    required this.isMe,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? json['sender']?['id'] ?? '',
      senderName: json['sender']?['name'] ?? json['senderName'] ?? 'User',
      senderAvatar: json['sender']?['avatar'] ?? json['senderAvatar'] ?? '/default_avatar.svg',
      text: json['text'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'] ?? 'text',
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      timeAgo: json['timeAgo'] ?? '',
      isMe: json['isMe'] ?? false,
    );
  }
}

class NotificationModel {
  final String id;
  final String actorName;
  final String actorAvatar;
  final String type;
  final String title;
  final String body;
  final String timeAgo;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.actorName,
    required this.actorAvatar,
    required this.type,
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      actorName: json['actor']?['name'] ?? '',
      actorAvatar: json['actor']?['avatar'] ?? '',
      type: json['type'] ?? 'LIKE',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
      isRead: json['isRead'] ?? false,
    );
  }
}

class SpaceModel {
  final String id;
  final String name;
  final String khmerName;
  final String mode;
  final String description;
  final String bannerUrl;
  final int memberCount;
  final int postCount;
  final List<String> features;

  SpaceModel({
    required this.id,
    required this.name,
    required this.khmerName,
    required this.mode,
    required this.description,
    required this.bannerUrl,
    required this.memberCount,
    required this.postCount,
    required this.features,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      khmerName: json['khmerName'] ?? '',
      mode: json['mode'] ?? 'PUBLIC',
      description: json['description'] ?? '',
      bannerUrl: json['bannerUrl'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      postCount: json['postCount'] ?? 0,
      features: (json['features'] as List<dynamic>?)?.map((f) => f.toString()).toList() ?? [],
    );
  }
}
