import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef PagingInfo = xmtp.PagingInfo;
typedef PagingInfoCursor = xmtp.Cursor;
typedef PagingInfoSortDirection = xmtp.SortDirection;

class Pagination {
  final int limit;
  final PagingInfoSortDirection direction;
  final DateTime? before;
  final DateTime? after;

  Pagination({
    required this.limit,
    this.direction = xmtp.SortDirection.SORT_DIRECTION_DESCENDING,
    this.before,
    this.after,
  });

  PagingInfo get pagingInfo {
    final page = xmtp.PagingInfo();

    page.limit = limit;

    page.direction = direction;

    return page;
  }
}
