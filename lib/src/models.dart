/// Data models mirroring reticulum-hub's Peer and Message records.
class Peer {
  final String destinationHash;
  final String name;
  final DateTime? lastSeen;
  final double? linkQuality;
  final int? hops;
  final String status;

  const Peer({
    required this.destinationHash,
    required this.name,
    this.lastSeen,
    this.linkQuality,
    this.hops,
    this.status = 'unknown',
  });

  factory Peer.fromJson(Map<String, dynamic> j) => Peer(
        destinationHash: (j['destination_hash'] ?? '').toString(),
        name: (j['name'] ?? j['destination_hash'] ?? 'Unknown').toString(),
        lastSeen: _date(j['last_seen']),
        linkQuality: (j['link_quality'] as num?)?.toDouble(),
        hops: (j['hops'] as num?)?.toInt(),
        status: (j['status'] ?? 'unknown').toString(),
      );
}

class ChatMessage {
  final String id;
  final String senderHash;
  final String recipientHash;
  final String body;
  final String direction; // inbound | outbound
  final DateTime sentAt;
  final bool delivered;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderHash,
    required this.recipientHash,
    required this.body,
    required this.direction,
    required this.sentAt,
    this.delivered = false,
    this.read = false,
  });

  bool get outbound => direction == 'outbound';

  /// The remote party of this message.
  String get peerHash => outbound ? recipientHash : senderHash;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] ?? '').toString(),
        senderHash: (j['sender_hash'] ?? '').toString(),
        recipientHash: (j['recipient_hash'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        direction: (j['direction'] ?? 'inbound').toString(),
        sentAt: _date(j['sent_at']) ?? DateTime.now(),
        delivered: j['delivered'] == true,
        read: j['read'] == true,
      );

  String get statusIcon => read ? '✓✓' : (delivered ? '✓' : '○');
}

class Conversation {
  final String peerHash;
  final String peerName;
  final ChatMessage? lastMessage;
  final int unread;

  const Conversation({
    required this.peerHash,
    required this.peerName,
    this.lastMessage,
    this.unread = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        peerHash: (j['peer_hash'] ?? '').toString(),
        peerName: (j['peer_name'] ?? j['peer_hash'] ?? 'Unknown').toString(),
        lastMessage: j['last_message'] is Map<String, dynamic>
            ? ChatMessage.fromJson(j['last_message'] as Map<String, dynamic>)
            : null,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

String formatAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
