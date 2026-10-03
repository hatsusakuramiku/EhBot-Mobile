import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 1x1 PNG（测试用最小合法位图）。
const String kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// 缩略图响应：合法 PNG。
http.Response tinyPngResponse() => http.Response.bytes(
  base64Decode(kTinyPngBase64),
  200,
  headers: <String, String>{'content-type': 'image/png'},
);

/// 构造 JSON 响应（UTF-8，带正确 content-type）。
http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );

/// 构造后端错误信封（`CONTRACT.md` §1）。
http.Response errorResponse(
  String code, {
  String message = '请求失败。',
  int status = 400,
  Object? details,
}) => jsonResponse(<String, Object?>{
  'error': <String, Object?>{
    'code': code,
    'message': message,
    'details': ?details,
  },
}, status: status);

Map<String, Object?> tokenJson({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int expiresIn = 43200,
}) => <String, Object?>{
  'access_token': access,
  'refresh_token': refresh,
  'token_type': 'Bearer',
  'expires_in': expiresIn,
};

Map<String, Object?> whoAmIJson({
  String username = 'admin',
  String kind = 'password',
  String? expiresAt,
  bool mustChangePassword = false,
}) => <String, Object?>{
  'username': username,
  'kind': kind,
  'expires_at': expiresAt,
  'must_change_password': mustChangePassword,
};

// ------------------------------------------------------------- M3 夹具与假后端

Map<String, Object?> candidateJson({
  String id = '11',
  String title = '某本子',
  String? coverHash = 'hash-a',
  bool approve = true,
  bool reject = true,
}) => <String, Object?>{
  'candidate_id': id,
  'title': title,
  'artist': '作者A',
  'category': '同人志',
  'language': 'chinese',
  'tags': <String>['tag1', 'tag2'],
  'status': <String, Object?>{
    'code': 'PENDING_REVIEW',
    'label': '待审核',
    'tone': 'waiting',
    'live': false,
  },
  'cover': coverHash == null
      ? null
      : <String, Object?>{
          'url': '/api/v1/thumbnails/$coverHash',
          'hash': coverHash,
        },
  'actions': <String, Object?>{'approve': approve, 'reject': reject},
};

Map<String, Object?> candidatesPageJson({
  List<Map<String, Object?>>? items,
  int total = 3,
  int page = 1,
  int pages = 1,
}) => <String, Object?>{
  'items': items ?? <Map<String, Object?>>[candidateJson()],
  'total': total,
  'page': page,
  'page_size': 30,
  'pages': pages,
  'counts': <String, Object?>{'total': total, 'pending_review': 1},
  'tab_counts': <String, Object?>{'all': total, 'pending': 1},
  'tab': 'pending',
  'sort': 'newest',
  'direction': 'desc',
  'search': '',
};

Map<String, Object?> jobJson({String id = '77', String label = '下载中'}) =>
    <String, Object?>{
      'job_id': id,
      'candidate_id': '11',
      'provider': <String, Object?>{'code': 'telegram', 'label': 'Telegram'},
      'state': <String, Object?>{
        'code': 'DOWNLOADING',
        'label': label,
        'tone': 'active',
        'live': true,
      },
      'progress_percent': 42,
      'error_message': '',
      'group': 'active',
      'note': null,
      'priority': 0,
      'updated_at': '2026-10-03T10:00:00Z',
    };

Map<String, Object?> summaryJson() => <String, Object?>{
  'candidates': <String, Object?>{
    'total': 7,
    'pending_review': 3,
    'approved': 2,
  },
  'activity': <String, Object?>{'downloads': 1, 'packing': 0, 'live': true},
  'attention': <String, Object?>{
    'total': 1,
    'items': <Map<String, Object?>>[jobJson()],
  },
  'connections': null,
  'startup_errors': <String>[],
};

Map<String, Object?> queueJson() => <String, Object?>{
  'downloads': <Map<String, Object?>>[
    <String, Object?>{
      'group': <String, Object?>{'code': 'active', 'label': '进行中'},
      'count': 1,
      'jobs': <Map<String, Object?>>[jobJson()],
    },
  ],
  'packing': <Object>[],
  'counts': <String, Object?>{'downloads': 1, 'packing': 0},
  'attention': <String, Object?>{'total': 0, 'reasons': <Object>[]},
  'live': true,
};

Map<String, Object?> downloadedJson() => <String, Object?>{
  'candidate_id': '11',
  'title': '已下载本',
  'artist': '作者A',
  'provider': <String, Object?>{'code': 'telegram', 'label': 'Telegram'},
  'state': <String, Object?>{
    'code': 'DOWNLOADED',
    'label': '已下载',
    'tone': 'success',
    'live': false,
  },
  'pack': <String, Object?>{
    'code': 'packed',
    'label': '已打包',
    'tone': 'success',
  },
  'cbz_path': '/library/a.cbz',
  'archive_path': '/a.zip',
  'archive_size': 123,
};

Map<String, Object?> workDetailJson() => <String, Object?>{
  'candidate_id': '11',
  'title': '某本子',
  'status': <String, Object?>{
    'code': 'PENDING_REVIEW',
    'label': '待审核',
    'tone': 'waiting',
    'live': false,
  },
  'stage': <String, Object?>{
    'code': 'REVIEW',
    'label': '审核',
    'tone': 'waiting',
    'live': false,
  },
  'filter_reason': '',
  'metadata': <Map<String, Object?>>[
    <String, Object?>{
      'field_label': '标题',
      'field_value': '某本子',
      'is_manual': false,
      'is_locked': false,
    },
  ],
  'timeline': <Map<String, Object?>>[
    <String, Object?>{
      'action_view': <String, Object?>{'label': '入库'},
      'reason': '收到消息',
      'created_at': '2026-10-03T09:00:00Z',
    },
  ],
  'jobs': <Object>[],
  'archive': null,
  'actions': <String, Object?>{'approve': true, 'reject': true},
  'live': false,
};

/// 覆盖四个页面 + 鉴权的假后端；未匹配的路径返回 404。
MockClient fakeBackend({void Function(http.Request request)? onRequest}) =>
    MockClient((http.Request request) async {
      onRequest?.call(request);
      final String path = request.url.path;
      if (path.endsWith('/auth/whoami')) {
        return jsonResponse(whoAmIJson(kind: 'api_key'));
      }
      if (path.contains('/thumbnails/')) {
        return tinyPngResponse();
      }
      if (path.endsWith('/summary')) {
        return jsonResponse(summaryJson());
      }
      if (path.endsWith('/candidates/batch')) {
        return jsonResponse(<String, Object?>{
          'action': 'approve',
          'requested': 1,
          'applied': <Map<String, Object?>>[
            <String, Object?>{'candidate_id': 11},
          ],
          'skipped': <Object>[],
        });
      }
      if (path.endsWith('/candidates')) {
        return jsonResponse(candidatesPageJson());
      }
      if (path.contains('/works/')) {
        return jsonResponse(workDetailJson());
      }
      if (path.endsWith('/queue')) {
        return jsonResponse(queueJson());
      }
      if (path.endsWith('/history')) {
        return jsonResponse(<String, Object?>{
          'items': <Map<String, Object?>>[jobJson(id: '88', label: '已完成')],
          'total': 1,
          'limit': 50,
        });
      }
      if (path.endsWith('/downloaded')) {
        return jsonResponse(<String, Object?>{
          'works': <Map<String, Object?>>[downloadedJson()],
          'total': 1,
          'tab': 'all',
          'counts': <String, Object?>{'all': 1},
          'live': false,
        });
      }
      return http.Response(
        '{"error":{"code":"NOT_FOUND","message":"no stub"}}',
        404,
      );
    });

/// 一律失败（503 + 错误信封）的假后端，用于错误态测试。
MockClient fakeBackendFailure() => MockClient(
  (http.Request request) async =>
      errorResponse('SERVICE_UNAVAILABLE', message: '服务器暂时不可用', status: 503),
);
